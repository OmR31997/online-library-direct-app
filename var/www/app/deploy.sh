#!/bin/bash
set -e

# Dynamically locate the repository root relative to this script's location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../../.." && pwd )"

echo "Navigating to repository root: $REPO_ROOT"
cd "$REPO_ROOT"

echo "Fetching latest code from GitHub..."
git fetch --all
git reset --hard origin/main

# Load environment variables if .env file exists
if [ -f .env ]; then
  echo "Loading environment variables..."
  set -a
  source .env
  set +a
fi

echo "Installing node modules..."
npm ci --legacy-peer-deps

echo "Generating Prisma Client..."
npx prisma generate

echo "Running database migrations..."
npx prisma migrate deploy || echo "Database migrations skipped or failed. Continuing..."

echo "Building the Next.js application..."
npm run build

echo "Starting/Restarting the application under PM2..."
# Delete the old process if it exists to avoid port/configuration conflicts, then start
PORT=3000 pm2 restart online-library-pm2 || PORT=3000 pm2 start npm --name "online-library-pm2" -- start

echo "Saving PM2 process list..."
pm2 save

echo "Deployment complete!"
