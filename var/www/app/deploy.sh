#!/bin/bash
set -e
cd /var/www/app
git fetch --all
git reset --hard origin/main
npm ci --only=production
pm2 restart app || pm2 start app.js --name "app"
