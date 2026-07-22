#!/bin/bash

set -euo pipefail

APP_NAME="${APP_NAME:?APP_NAME is required}"
APP_DIR="${APP_DIR:?APP_DIR is required}"
BRANCH_NAME="${BRANCH_NAME:?BRANCH_NAME is required}"

cleanup_space() {
    echo "Cleaning up build and cache artifacts to avoid ENOSPC..."

    rm -rf node_modules || true
    rm -rf .next || true
    rm -rf .turbo || true
    rm -rf .cache || true
    rm -rf "$HOME/.npm/_cacache" || true
    rm -rf "$HOME/.npm/_logs" || true

    if command -v docker >/dev/null 2>&1; then
        docker system prune -af || true
        docker builder prune -af || true
    fi

    if command -v journalctl >/dev/null 2>&1; then
        sudo journalctl --vacuum-size=50M || true
    fi

    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get clean || true
    fi

    if command -v npm >/dev/null 2>&1; then
        npm cache clean --force || true
    fi

    if command -v pm2 >/dev/null 2>&1; then
        pm2 flush || true
    fi
}

rollback_to_previous_commit() {
    local exit_code="$1"

    trap - ERR
    echo "Deployment failed. Rolling back local checkout..."
    if [ -n "${PREVIOUS_COMMIT:-}" ]; then
        git checkout -q "$PREVIOUS_COMMIT" || true
        echo "Rolled back to $PREVIOUS_COMMIT"
    fi

    exit "$exit_code"
}

echo "======================================"
echo "Deploying $APP_NAME"
echo "Branch: $BRANCH_NAME"
echo "Directory: $APP_DIR"
echo "======================================"

cd "$APP_DIR"

if [ ! -f ".env" ]; then
    echo ".env file not found. Please create it before deploying."
    exit 1
fi

PREVIOUS_COMMIT="$(git rev-parse HEAD)"
REMOTE_COMMIT="$(git ls-remote origin "refs/heads/$BRANCH_NAME" | awk 'NR==1 { print $1 }')"

if [ -z "$REMOTE_COMMIT" ]; then
    echo "Unable to resolve remote commit for branch '$BRANCH_NAME'."
    exit 1
fi

if [ "$PREVIOUS_COMMIT" = "$REMOTE_COMMIT" ]; then
    echo "No new commit found on origin/$BRANCH_NAME."
    echo "Current commit is already up to date: $PREVIOUS_COMMIT"
    exit 0
fi

echo "New commit detected:"
echo "Current: $PREVIOUS_COMMIT"
echo "Remote : $REMOTE_COMMIT"

trap 'rollback_to_previous_commit $?' ERR

cleanup_space

if command -v df >/dev/null 2>&1; then
    df -h "$APP_DIR" || true
fi

echo "Fetching latest code..."
git -c gc.auto=0 fetch --prune --depth=1 origin "$BRANCH_NAME"
git checkout -q "$REMOTE_COMMIT"

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

trap - ERR

echo "======================================"
echo "Deployment completed successfully!"
echo "======================================"
