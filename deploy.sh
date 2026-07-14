#!/bin/bash

# Exit on error
set -e

cleanup_space(){
        echo "======================================"
        echo "Performing system cleanup to prevent disk full (ENOSPC) errors..."
        echo "======================================"
        
        # Stop and remove existing Docker containers and images to free up space
        if command -v docker >/dev/null 2>&1; then
                echo "Stopping and removing existing Docker web container and images to free up space..."
                sudo docker rm -f online-library-app || true
                sudo docker rmi -f online-library:latest || true
                sudo docker system prune -a -f || true
                sudo docker builder prune -a -f || true
        fi
        
        # Clean Next.js build cache and temporary artifacts
        echo "Removing old Next.js build caches..."
        rm -rf .next || true
        rm -rf online-library-pm2/.next || true
        
        # Clean npm cache
        if command -v npm >/dev/null 2>&1; then
                echo "Cleaning npm cache..."
                npm cache clean --force || true
        fi
        
        # Flush PM2 logs to save space
        if command -v pm2 >/dev/null 2>&1; then
                echo "Flushing PM2 logs..."
                pm2 flush || true
        fi
        
        # Clean apt cache and autoremove unused packages
        if command -v apt-get >/dev/null 2>&1; then
                echo "Cleaning apt packages cache and autoremoving..."
                sudo apt-get autoremove -y || true
                sudo apt-get clean || true
        fi

        # Vacuum system journal logs to 50MB
        if command -v journalctl >/dev/null 2>&1; then
                echo "Cleaning system logs..."
                sudo journalctl --vacuum-size=50M || true
        fi
}

setup_swap(){
        # Check if swap space is already active
        if [ $(free -m | awk '/^Swap:/{print $2}') -eq 0 ]; then
                echo "======================================"
                echo "Creating 2GB swap space to prevent Out-Of-Memory (137) errors..."
                echo "======================================"
                # Create a 2GB swap file (uses fallocate first, falls back to dd if not supported)
                sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
                sudo chmod 600 /swapfile
                sudo mkswap /swapfile
                sudo swapon /swapfile
                # Make swap persistent across system reboots
                echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
                echo "Swap space successfully enabled!"
        else
                echo "Swap space is already configured."
        fi
}

code_clone(){
        echo "======================================"
        echo "Cloning or updating repository..."
        echo "======================================"
        if [ -d "online-library-pm2" ]; then
                echo "The code directory already exists. Pulling latest changes..."
                cd online-library-pm2
                git pull
                cd ..
        else
                git clone https://github.com/OmR31997/online-library.git online-library-pm2
        fi
}

depend_installation(){
        echo "======================================"
        echo "Installing dependencies (Node.js, PM2, Nginx)..."
        echo "======================================"
        sudo apt-get update
        sudo apt-get install -y curl nginx
        
        # Install Node.js 22 or upgrade if older than v22
        local install_node=false
        if ! command -v node >/dev/null 2>&1; then
                install_node=true
        else
                local current_ver=$(node -v | cut -d'v' -f2)
                local major_ver=$(echo "$current_ver" | cut -d'.' -f1)
                if [ "$major_ver" -lt 22 ]; then
                        echo "Current Node.js version ($current_ver) is less than 22. Upgrading to Node.js 22..."
                        install_node=true
                fi
        fi

        if [ "$install_node" = true ]; then
                echo "Installing Node.js 22..."
                curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
                sudo apt-get install -y nodejs
        else
                echo "Node.js is already installed and matches required version: $(node -v)"
        fi

        # Install PM2 globally if not already installed
        if ! command -v pm2 >/dev/null 2>&1; then
                echo "Installing PM2 globally..."
                sudo npm install -g pm2
        else
                echo "PM2 is already installed: $(pm2 -v)"
        fi
}

required_restarts(){
        echo "======================================"
        echo "Configuring permissions and services..."
        echo "======================================"
        sudo systemctl enable nginx
        sudo systemctl restart nginx
        
        # Configure PM2 to start on system boot
        echo "Setting up PM2 startup system service..."
        pm2 startup || true
}

configure_nginx(){
        echo "======================================"
        echo "Automating Nginx reverse proxy configuration..."
        echo "======================================"
        
        # Write default Nginx site configuration mapping port 80 to port 8000
        sudo tee /etc/nginx/sites-available/default > /dev/null << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        
        # Forward client IP headers
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

        # Verify Nginx configuration syntax and restart service
        sudo nginx -t
        sudo systemctl restart nginx
}

deploy() {
        echo "======================================"
        echo "Deploying application with PM2..."
        echo "======================================"
        
        # Ensure we are inside the repository directory
        cd online-library-pm2

        # Check if .env file exists
        if [ ! -f .env ]; then
                echo "Warning: .env file is missing. Creating from .env.example..."
                if [ -f .env.example ]; then
                        cp .env.example .env
                        echo "Created .env file. Please edit it with your database credentials."
                else
                        echo "Error: No .env.example found. Please create a .env file."
                        exit 1
                fi
        fi

        # Load environment variables from .env file for build and runtime
        if [ -f .env ]; then
                echo "Sourcing environment variables..."
                set -a
                source .env
                set +a
        fi

        # Install project node dependencies
        echo "Installing node modules..."
        npm ci --legacy-peer-deps

        # Generate Prisma Client
        echo "Generating Prisma Client..."
        npx prisma generate

        # Apply migrations if database is online
        echo "Running Prisma migrations..."
        npx prisma migrate deploy || echo "Prisma migration failed or skipped. Continuing build..."

        # Remove old build files and Next.js build cache to free up space
        echo "Removing old .next build directory to free up space..."
        rm -rf .next || true

        # Build application
        echo "Building Next.js application..."
        npm run build

        # Start/Restart application under PM2
        echo "Starting Next.js server on port 8000 under PM2..."
        pm2 delete online-library-pm2 || true
        PORT=8000 pm2 start npm --name "online-library-pm2" -- start

        # Save PM2 process list to persist across reboots
        echo "Saving PM2 process list..."
        pm2 save

        echo "======================================"
        echo "Application successfully deployed with PM2 on port 8000!"
        echo "======================================"
}

configure_ssl(){
        # Check if DOMAIN argument or environment variable is set
        local domain="${1:-$DOMAIN}"
        
        if [ -n "$domain" ]; then
                echo "======================================"
                echo "Configuring SSL for domain: $domain..."
                echo "======================================"
                
                # Install certbot if not present
                if ! command -v certbot >/dev/null 2>&1; then
                        echo "Installing Certbot..."
                        sudo apt-get install -y certbot python3-certbot-nginx
                fi
                
                # Run Certbot to configure SSL on Nginx
                # --register-unsafely-without-email is used to avoid interactive email prompt
                sudo certbot --nginx -d "$domain" --non-interactive --agree-tos --register-unsafely-without-email || {
                        echo "Warning: Certbot SSL configuration failed. Please verify that your domain DNS is correctly pointed to this server's IP address."
                }
                
                echo "SSL configuration process completed for $domain."
        else
                echo "======================================"
                echo "Skipping SSL configuration (No domain provided)."
                echo "To configure SSL, run: ./deploy.sh <your-domain.com>"
                echo "======================================"
        fi
}

# Run execution flow
cleanup_space
setup_swap
code_clone
depend_installation
required_restarts
configure_nginx
deploy
configure_ssl "$1"
