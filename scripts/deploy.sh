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

pm2 reload "$APP_NAME" --update-env

echo "Deployment completed successfully!"