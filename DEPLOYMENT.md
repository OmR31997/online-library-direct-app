# Deployment & Operations Guide (PM2 Edition)

This is an interactive software engineering learning roadmap, tutorial, and quiz platform built using Next.js, Prisma (PostgreSQL), and Valkey/Redis, configured for PM2 deployment.

## Requirements
- **Node.js**: `22.x` or later (for local host development and production runner)
- **PM2**: `5.x` or later
- **PostgreSQL**: `13.x` or later (managed database recommended, e.g., Aiven)
- **Valkey / Redis**: `7.x` or later (managed caching recommended, e.g., Aiven)

## Installation & Getting Started

1. **Clone the repository**:
   ```bash
   git clone <repository-url> online-library-pm2
   cd online-library-pm2
   ```

2. **Configure environment settings**:
   Copy the example file to `.env` and fill in the values:
   ```bash
   cp .env.example .env
   ```

3. **Install dependencies**:
   ```bash
   npm install
   ```

4. **Run database migrations and seed**:
   Refer to the Database Migrations section below.

5. **Start development server**:
   ```bash
   npm run dev
   ```

---

## 1. Environment Configuration

The application requires various environment variables for database connectivity, caching, session encryption, and authentication.

### Local Development / Production (`.env`)
The `.env` file at the project root is loaded by Prisma and Next.js, which connects directly to your databases (e.g., Aiven PostgreSQL & Valkey).

Make sure the following variables are configured properly:
```ini
# PostgreSQL Database Settings
PG_HOST="your-pg-host.aivencloud.com"
PG_PORT="18936"
PG_USER="avnadmin"
PG_PASSWORD="your-secure-password"
PG_DB_NAME="defaultdb"
PG_SSL_MODE="require"
PG_CA_CERTIFICATE="pem/ca.pem" # Required for SSL verification
PG_CONNECTION_LIMIT="20"

# Valkey / Redis Settings
REDIS_HOST="your-valkey-host.aivencloud.com"
REDIS_PORT="18937"
REDIS_USER="default"
REDIS_PASSWORD="your-valkey-password"

# Security and JWT Session Management
JWT_SECRET="local-development-jwt-secret-key-32-chars-long"
NEXTAUTH_SECRET="local-development-nextauth-secret-key-32-chars-long"
```

> [!NOTE]
> Ensure the public CA certificate used by database connections is located under `pem/ca.pem`.

---

## 2. Database Migrations and Seeding

Before running the application, you must apply the database migrations to set up the schema and optional seed data (e.g., initial roadmaps, tutorials, and quizzes).

### Run Migrations (Local Host)
To apply migrations on the database defined in your local `.env`:
```bash
# Apply pending database migrations
npx prisma migrate deploy

# Seed initial application data (roadmaps, tutorials, quizzes)
npx prisma db seed
```

---

## 3. Automated PM2-based Deployment (`deploy.sh`)

An automated bash script is included at the root of the project to simplify host-level deployments without Docker. It installs Node.js, PM2, and Nginx, runs database migrations, builds the Next.js app locally, and spawns the application process managed by PM2 on port `8000`.

To run the automated script:

1. **Make it executable**:
   ```bash
   chmod +x deploy.sh
   ```

2. **Run the script** (Standard HTTP on Port 80):
   ```bash
   ./deploy.sh
   ```

3. **Run the script with SSL/HTTPS configuration** (Optional, requires a domain pointed to the server's IP):
   ```bash
   ./deploy.sh yourdomain.com
   ```

> [!IMPORTANT]
> Ensure your `.env` file contains correct database and cache configuration before running the script. The PM2 process dynamically reads environment variables sourced from the `.env` file during startup.

---

## 4. Troubleshooting & Useful Commands

### Database Connection Failures
If the application cannot connect to the database:
1. Ensure the PostgreSQL host is accessible and credentials match.
2. Verify that `PG_CA_CERTIFICATE` correctly points to the location of the CA certificate.

### PM2 Commands
Use the following commands to monitor and manage the application:
```bash
# List all running PM2 processes
pm2 list

# View logs in real-time
pm2 logs online-library-pm2

# Restart the application
pm2 restart online-library-pm2

# Stop the application
pm2 stop online-library-pm2
```

---

## 5. Nginx Reverse Proxy Setup

To expose the application on standard web ports (`80` / `443`), install and configure Nginx as a reverse proxy.

### Step 5.1: Install Nginx
On Ubuntu / Debian-based systems:
```bash
sudo apt-get update
sudo apt install nginx -y
```

### Step 5.2: Configure Reverse Proxy
Create or edit your site configuration (e.g., `/etc/nginx/sites-available/online-library-pm2`):
```nginx
server {
    listen 80;
    server_name your-domain.com; # Replace with your actual domain or IP

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        
        # Real IP forwarding
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the configuration and restart Nginx:
```bash
# Link to sites-enabled
sudo ln -s /etc/nginx/sites-available/online-library-pm2 /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Restart Nginx service
sudo systemctl restart nginx
```
