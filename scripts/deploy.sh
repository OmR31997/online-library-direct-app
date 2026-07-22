#!/bin/bash

set -euo pipefail

APP_NAME="${APP_NAME:?APP_NAME is required}"
APP_DIR="${APP_DIR:?APP_DIR is required}"
BRANCH_NAME="${BRANCH_NAME:?BRANCH_NAME is required}"

cd "$APP_DIR"

git fetch origin
git checkout "$BRANCH_NAME"
git pull --ff-only origin "$BRANCH_NAME"

npm ci
npm run build 

if pm2 describe "$APP_NAME" > /dev/null 2>&1; then
    echo "Reloading existing PM2 application..."
    pm2 reload "$APP_NAME" --update-env
else
    echo "Starting application for the first time..."
    pm2 start npm --name "$APP_NAME" -- start
fi

pm2 save

echo "Deployment completed successfully!"