#!/bin/bash

set -euo pipefail

APP_NAME="${APP_NAME:?APP_NAME is required}"
APP_DIR="${APP_DIR:?APP_DIR is required}"
BRANCH_NAME="${BRANCH_NAME:?BRANCH_NAME is required}"

cleanup_space() {
    echo "Cleaning up build and cache artifacts to avoid ENOSPC..."

    # Remove Next.js build output and transient caches from previous runs.
    rm -rf .next .turbo .cache .next/cache node_modules/.cache || true
    rm -f npm-debug.log yarn-error.log pnpm-debug.log || true

    if command -v npm >/dev/null 2>&1; then
        npm cache clean --force || true
    fi

    if command -v pm2 >/dev/null 2>&1; then
        pm2 flush || true
    fi

    # Trim any stray temporary files in the app directory.
    find . -maxdepth 1 -type f \( -name "*.log" -o -name "*.tmp" -o -name "*.temp" \) -delete 2>/dev/null || true
}

echo "======================================"
echo "Deploying $APP_NAME"
echo "Branch: $BRANCH_NAME"
echo "Directory: $APP_DIR"
echo "======================================"

cd "$APP_DIR"

echo "Fetching latest code..."
git fetch origin
git checkout "$BRANCH_NAME"
git pull --ff-only origin "$BRANCH_NAME"

if [ ! -f ".env" ]; then
    echo ".env file not found. Please create it before deploying."
    exit 1
fi

cleanup_space

echo "Installing dependencies..."
npm ci --legacy-peer-deps --no-audit --no-fund

echo "Building application..."
npm run build 

if pm2 describe "$APP_NAME" > /dev/null 2>&1; then
    echo "Reloading existing PM2 application..."
    pm2 reload "$APP_NAME" --update-env
else
    echo "Starting application for the first time..."
    pm2 start npm --name "$APP_NAME" -- start
fi

pm2 save

echo "======================================"
echo "Deployment completed successfully!"
echo "======================================"
