# AWS.yml

Absolutely. I'll explain this GitHub Actions workflow **line by line**, just like the deployment script.

---

# File Purpose

This file is typically stored at:

```text
.github/workflows/aws.yml
```

GitHub automatically detects any YAML files inside the `.github/workflows` directory and runs them when the configured events occur.

This workflow performs:

1. **CI (Continuous Integration)** – verifies that the project is healthy.
2. **CD (Continuous Deployment)** – deploys the latest code to your AWS EC2 server.

---

# 1.

```yaml
name: CI/CD - Deploy AWS EC2
```

## Meaning

This is the workflow's display name.

You'll see it on the **GitHub Actions** page.

Example:

```text
Actions
└── CI/CD - Deploy AWS EC2
```

It does **not** affect how the workflow runs—it's only a label.

---

# 2.

```yaml
on:
```

## Meaning

Defines **when this workflow should run**.

Think of it as the trigger.

---

# 3.

```yaml
push:
```

Run this workflow whenever code is **pushed**.

Example:

```bash
git push origin dev
```

or

```bash
git push origin main
```

Both trigger the workflow if the branch matches.

---

# 4.

```yaml
branches: [main, dev, stage]
```

Only run when pushing to these branches:

- `main`
- `dev`
- `stage`

Example:

```bash
git push origin dev
```

✅ Runs

```bash
git push origin stage
```

✅ Runs

```bash
git push origin feature/login
```

❌ Does not run

---

# 5.

```yaml
permissions:
```

Defines the permissions granted to the GitHub Actions runner.

GitHub follows the **principle of least privilege**, so you should grant only what is needed.

---

# 6.

```yaml
contents: read
```

Allows the workflow to **read** the repository contents.

It can:

- Clone the repository
- Read files

It **cannot**:

- Push commits
- Delete branches
- Modify the repository

---

# 7.

```yaml
env:
```

Defines environment variables available throughout the workflow.

---

# 8.

```yaml
NODE_VERSION: 22
```

Creates a global environment variable.

Equivalent in Linux:

```bash
export NODE_VERSION=22
```

Later you can reference it as:

```yaml
${{ env.NODE_VERSION }}
```

Instead of hardcoding `22` in multiple places.

---

# 9.

```yaml
jobs:
```

A workflow consists of one or more **jobs**.

Jobs run independently unless you specify dependencies.

In this workflow there are two jobs:

```
CI
↓

CD
```

---

# 10.

```yaml
ci:
```

Defines the first job.

Its ID is `ci`.

---

# 11.

```yaml
name: Continuous Integration (Inspection)
```

A human-readable name shown in the GitHub Actions UI.

---

# 12.

```yaml
runs-on: ubuntu-latest
```

GitHub creates a **fresh Ubuntu virtual machine** for this job.

Think of it like:

```
GitHub
   │
Creates
   │
Ubuntu VM
   │
Runs CI
   │
Deletes VM
```

Each workflow run starts with a clean machine.

---

# 13.

```yaml
steps:
```

Lists the commands/actions that make up the job.

They execute **in order**.

---

# 14.

```yaml
- name: Checkout Repository/Source Code
```

This is just the display name of the step.

---

# 15.

```yaml
uses: actions/checkout@v4
```

Downloads your repository into the GitHub runner.

Without this, the VM would have no project files.

---

# 16.

```yaml
- name: Set up Node.js Environment
```

Another descriptive step name.

---

# 17.

```yaml
uses: actions/setup-node@v4
```

Installs Node.js on the runner.

Without it:

```bash
node
```

would not be available.

---

# 18.

```yaml
with:
```

Passes configuration to the action.

---

# 19.

```yaml
node-version: ${{ env.NODE_VERSION }}
```

Uses the value defined earlier:

```yaml
NODE_VERSION: 22
```

So this installs Node.js **22**.

---

# 20.

```yaml
cache: "npm"
```

Enables npm dependency caching.

Normally:

```
Run 1

Download
↓

node_modules
```

Next run:

```
Cache
↓

Restore
↓

Faster install
```

This significantly speeds up repeated CI runs.

---

# 21.

```yaml
- name: Install Dependencies
```

Step label.

---

# 22.

```yaml
run: npm ci --legacy-peer-deps
```

Runs:

```bash
npm ci --legacy-peer-deps
```

`npm ci`

- Deletes existing `node_modules`
- Installs exactly what's in `package-lock.json`
- Faster and more reproducible than `npm install`

`--legacy-peer-deps`

Ignores strict peer dependency conflicts.

---

# 23.

```yaml
- name: Generate Prisma Client
```

Step label.

---

# 24.

```yaml
run: npx prisma generate
```

Generates the Prisma Client based on your Prisma schema.

Without this, imports like:

```ts
import { PrismaClient } from "@prisma/client";
```

may fail if the client hasn't been generated.

---

# 25.

```yaml
# - name: Lint
#   run: npm run lint
```

Currently commented out.

If enabled:

```bash
npm run lint
```

checks code quality and style.

---

# 26.

```yaml
# - name: Run Tests
```

Would execute:

```bash
npm test
```

to run automated tests.

---

# 27.

```yaml
# - name: Build Application
```

Would build the application.

Example:

```bash
npm run build
```

This verifies that the project compiles successfully before deployment.

---

# 28.

```yaml
# Upload Build Artifact
```

Artifacts are files produced by one job that another job can download.

Example flow:

```
CI
↓

Build
↓

Upload Artifact
↓

CD
↓

Download Artifact
```

Useful when you want to deploy the exact build that CI created.

---

# 29.

```yaml
cd:
```

Defines the second job.

---

# 30.

```yaml
needs: ci
```

This is one of the most important lines.

It means:

> **Don't start CD until CI finishes successfully.**

Flow:

```
Push
↓

CI
↓

Success?

Yes
↓

CD

No
↓

Stop
```

---

# 31.

```yaml
runs-on: ubuntu-latest
```

Creates another fresh Ubuntu runner for deployment.

Each job gets its own separate VM.

---

# 32.

```yaml
- name: Setup SSH
```

Prepares secure SSH access to the EC2 server.

---

# 33.

```yaml
mkdir -p ~/.ssh
```

Creates the SSH directory if it doesn't exist.

`-p` means it's okay if the directory already exists.

---

# 34.

```yaml
echo "${{ secrets.EC2_SSH_KEY }}" > ~/.ssh/id_rsa
```

Writes the private SSH key (stored securely in GitHub Secrets) into the runner.

---

# 35.

```yaml
chmod 600 ~/.ssh/id_rsa
```

Sets secure permissions:

- Owner: read/write
- Others: no access

SSH refuses to use a private key if it's too permissive.

---

# 36.

```yaml
ssh-keyscan -H ${{ secrets.EC2_HOST }} >> ~/.ssh/known_hosts
```

Adds the EC2 server's public host key to `known_hosts`.

This avoids the interactive prompt:

```
Are you sure you want to continue connecting (yes/no)?
```

which would otherwise block automation.

---

# 37.

```yaml
- name: Deploy
```

Starts the deployment step.

---

# 38.

```yaml
ssh ${{ secrets.EC2_USER }}@${{ secrets.EC2_HOST }} << EOF
```

Opens an SSH connection to the EC2 server.

Example:

```bash
ssh ubuntu@13.233.xxx.xxx
```

`<< EOF` starts a **here document**, allowing multiple commands to be sent over the SSH session.

---

# 39.

```bash
export APP_NAME="${{ secrets.APP_NAME }}"
```

Makes the application name available as an environment variable on the EC2 server.

Example:

```bash
export APP_NAME=online-library
```

---

# 40.

```bash
export APP_DIR="$HOME/${{ secrets.APP_NAME }}"
```

Constructs the application directory.

Example:

```bash
/home/ubuntu/online-library
```

Notice the escaped `$HOME` (`\$HOME`)—it's expanded **on the EC2 server**, not by GitHub Actions.

---

# 41.

```bash
export BRANCH_NAME="${{ github.ref_name }}"
```

Gets the branch that triggered the workflow.

Examples:

```text
main
```

or

```text
dev
```

Your `deploy.sh` then executes:

```bash
git checkout "$BRANCH_NAME"
git pull origin "$BRANCH_NAME"
```

so the correct branch is deployed.

---

# 42.

```bash
bash "$APP_DIR/scripts/deploy.sh"
```

Runs your deployment script on the EC2 server.

That script:

- Cleans old caches and build files
- Fetches the latest code
- Checks out the correct branch
- Pulls updates
- Verifies the `.env` file
- Installs dependencies
- Builds the application
- Reloads or starts the app with PM2
- Saves the PM2 process list

---

# 43.

```yaml
EOF
```

Ends the here document, closes the SSH command block, and the workflow finishes.

---

# Complete workflow execution

```text
Developer
    │
git push origin dev
    │
    ▼
GitHub detects push
    │
    ▼
Start Workflow
    │
    ▼
───────────────
CI Job
───────────────
│
├── Checkout repository
├── Install Node.js
├── Restore npm cache
├── Install dependencies
├── Generate Prisma Client
├── (Optional) Lint
├── (Optional) Test
└── (Optional) Build
    │
    ▼
CI Successful?
    │
 ┌──┴──────────┐
 │             │
No            Yes
 │             │
Stop           ▼
        ───────────────
        CD Job
        ───────────────
        │
        ├── Configure SSH
        ├── Connect to EC2
        ├── Export environment variables
        └── Execute deploy.sh
                │
                ├── Clean caches
                ├── Fetch latest code
                ├── Checkout branch
                ├── Pull updates
                ├── Install dependencies
                ├── Build application
                ├── Reload/Start PM2
                └── Save PM2 state
                │
                ▼
        Deployment Complete
```

This design cleanly separates responsibilities: the **GitHub Actions workflow (`aws.yml`) orchestrates the pipeline** (when to run, in what order, and on which server), while **`deploy.sh` performs the deployment logic on the EC2 machine**. This separation makes the deployment easier to maintain, test, and reuse.

# scripts/Deploy.sh

This is a production deployment script written in Bash. It automates the deployment of your Node.js/Next.js application on an EC2 server.

I'll explain it **line by line**.

---

# 1. Shebang

```bash
#!/bin/bash
```

### Meaning

Tells Linux to execute this script using the **Bash shell**.

Without this line, Linux may use another shell (`sh`, `dash`) which might not support Bash features.

---

# 2.

```bash
set -euo pipefail
```

This is one of the most important lines in production scripts.

It enables three safety options.

---

## `-e`

```bash
set -e
```

Meaning:

> Exit immediately if any command fails.

Example

Without `-e`

```bash
mkdir app
cd app
cd wrong_folder
npm install
echo "Done"
```

Output

```
cd: wrong_folder: No such file
npm install...
Done
```

Even though something failed, the script continued.

---

With `-e`

```
cd: wrong_folder: No such file
```

Script stops immediately.

This prevents deploying a broken application.

---

## `-u`

```bash
set -u
```

Means

> Treat undefined variables as errors.

Example

```bash
echo $APP_NAME
```

If APP_NAME isn't defined

Without `-u`

```
(empty)
```

With `-u`

```
APP_NAME: unbound variable
```

This prevents accidental empty values.

---

## `-o pipefail`

Normally,

```bash
command1 | command2
```

returns the exit status of the **last** command only.

Example

```bash
false | true
```

Normally

```
Exit code = 0
```

Even though `false` failed.

With

```bash
set -o pipefail
```

the pipeline fails if **any command** fails.

Much safer.

---

# 3.

```bash
APP_NAME="${APP_NAME:?APP_NAME is required}"
```

This is parameter expansion.

Meaning

> APP_NAME must exist.

If not,

```
APP_NAME is required
```

and script exits.

---

Example

Suppose

```bash
export APP_NAME=myapp
```

Then

```
APP_NAME=myapp
```

---

If missing

```
APP_NAME is required
```

---

Same thing here

```bash
APP_DIR="${APP_DIR:?APP_DIR is required}"
```

Means deployment folder is mandatory.

Example

```
/home/ubuntu/my-app
```

---

Same here

```bash
BRANCH_NAME="${BRANCH_NAME:?BRANCH_NAME is required}"
```

Means

```
main
dev
production
```

must be supplied.

---

# 4.

```bash
cleanup_space() {
```

Defines a Bash function named

```
cleanup_space
```

Nothing runs yet.

The function runs only when called.

---

# 5.

```bash
echo "Cleaning up build and cache artifacts to avoid ENOSPC..."
```

Prints

```
Cleaning up build and cache artifacts...
```

ENOSPC means

```
Error No Space Left On Device
```

Exactly the error you encountered on EC2.

---

# 6.

```bash
rm -rf .next .turbo .cache .next/cache node_modules/.cache || true
```

Deletes old build folders.

Let's understand each one.

---

### `rm`

Remove files/directories.

---

### `-r`

Recursive delete.

Deletes folders.

---

### `-f`

Force delete.

No confirmation.

---

Deletes

```
.next
```

Next.js build output.

---

Deletes

```
.turbo
```

TurboRepo cache.

---

Deletes

```
.cache
```

General cache.

---

Deletes

```
.next/cache
```

Webpack cache.

---

Deletes

```
node_modules/.cache
```

Package cache.

---

## Why?

Old builds consume lots of storage.

Removing them frees disk space before a new build.

---

## `|| true`

Very important.

Suppose

```
.next
```

doesn't exist.

Normally

```
rm
```

returns an error.

Because

```
set -e
```

is enabled,

the script would stop.

Instead,

```bash
rm ... || true
```

means

If rm fails,

pretend everything is okay.

Continue.

---

# 7.

```bash
rm -f npm-debug.log yarn-error.log pnpm-debug.log || true
```

Deletes package manager log files.

```
npm-debug.log

yarn-error.log

pnpm-debug.log
```

These are only debugging logs.

Safe to delete.

---

# 8.

```bash
if command -v npm >/dev/null 2>&1; then
```

Checks

```
Is npm installed?
```

---

### `command -v`

Searches executable.

Example

```
command -v node
```

returns

```
/usr/bin/node
```

---

### `>/dev/null`

Discard output.

---

### `2>&1`

Discard errors too.

Nothing prints.

---

# 9.

```bash
npm cache clean --force || true
```

Deletes npm cache.

Useful if cache becomes corrupted or huge.

---

# 10.

```bash
if command -v pm2 >/dev/null 2>&1; then
```

Checks

```
Is PM2 installed?
```

---

# 11.

```bash
pm2 flush
```

Deletes PM2 log contents.

Not processes.

Only logs.

---

# 12.

```bash
rm -rf "$HOME/.pm2/logs"/*
```

Deletes PM2 log files.

These logs can grow very large over time.

---

# 13.

```bash
rm -rf "$HOME/.cache"/*
```

Deletes Linux user cache.

---

Deletes

```
~/.cache
~/.cache/npm
~/.npm/_cacache
```

Useful because npm caches can consume hundreds of MBs.

---

# 14.

```bash
find . -maxdepth 1 -type f \
\( -name "*.log" -o -name "*.tmp" -o -name "*.temp" \) \
-delete
```

Finds files only in the current directory (`-maxdepth 1`) that end with `.log`, `.tmp`, or `.temp` and deletes them.

---

# 15.

```bash
}
```

Ends the `cleanup_space` function.

---

# 16.

```bash
fetch_latest_code() {
```

Starts another function.

Purpose:

Safely fetch the latest Git changes, with one cleanup-and-retry if disk space causes the first fetch to fail.

---

# 17.

```bash
echo "Fetching latest code..."
```

Displays a status message.

---

# 18.

```bash
if git fetch origin; then
    return 0
fi
```

Attempts to download the latest commits from the remote named `origin` without changing your working files.

If successful, `return 0` exits the function immediately.

---

# 19.

```bash
echo "git fetch failed, trying cleanup and one retry..."
```

Runs only if the first `git fetch` fails.

---

# 20.

```bash
cleanup_space
```

Calls the earlier function to free disk space.

---

# 21.

```bash
git fetch origin
```

Retries the fetch once after cleanup.

If this second attempt fails, `set -e` causes the script to stop.

---

# 22.

```bash
}
```

Ends the `fetch_latest_code` function.

---

# 23.

```bash
echo "======================================"
echo "Deploying $APP_NAME"
echo "Branch: $BRANCH_NAME"
echo "Directory: $APP_DIR"
echo "======================================"
```

Prints deployment information, for example:

```
======================================
Deploying online-library
Branch: dev
Directory: /home/ubuntu/online-library
======================================
```

---

# 24.

```bash
cd "$APP_DIR"
```

Changes into the application directory.

Quotes protect paths containing spaces.

---

# 25.

```bash
cleanup_space
```

Runs the cleanup before deployment begins.

---

# 26.

```bash
fetch_latest_code
```

Fetches the latest Git metadata, retrying once after cleanup if needed.

---

# 27.

```bash
git checkout "$BRANCH_NAME"
```

Switches to the deployment branch (for example, `dev` or `main`).

---

# 28.

```bash
git pull --ff-only origin "$BRANCH_NAME"
```

Updates the local branch.

The `--ff-only` option allows only a **fast-forward** update. If the local branch has diverged from the remote, Git refuses to merge automatically, which helps keep deployments predictable.

---

# 29.

```bash
if [ ! -f ".env" ]; then
```

Checks whether the `.env` file exists.

- `-f` → file exists.
- `!` → logical NOT.

So this means: "If `.env` does **not** exist..."

---

# 30.

```bash
echo ".env file not found. Please create it before deploying."
exit 1
```

Prints an error and exits with a non-zero status.

This prevents starting an application without required environment variables.

---

# 31.

```bash
echo "Installing dependencies..."
```

Displays the next deployment step.

---

# 32.

```bash
npm ci --legacy-peer-deps --no-audit --no-fund
```

Installs dependencies exactly as listed in `package-lock.json`.

- `npm ci` → clean, reproducible install (recommended for CI/CD).
- `--legacy-peer-deps` → ignores strict peer dependency conflicts.
- `--no-audit` → skips the security audit to save time.
- `--no-fund` → suppresses funding messages.

---

# 33.

```bash
echo "Building application..."
```

Shows that the build phase is starting.

---

# 34.

```bash
npm run build
```

Runs the project's build script (for example, creating the optimized Next.js production build).

---

# 35.

```bash
if pm2 describe "$APP_NAME" > /dev/null 2>&1; then
```

Checks whether a PM2 process with the given application name already exists.

Output and errors are discarded.

---

# 36.

```bash
pm2 reload "$APP_NAME" --update-env
```

If the app is already running:

- Reloads it with minimal downtime.
- Applies any updated environment variables because of `--update-env`.

---

# 37.

```bash
else
    pm2 start npm --name "$APP_NAME" -- start
fi
```

If the application isn't already managed by PM2, it starts it for the first time by running:

```bash
npm start
```

and assigns the PM2 process the name stored in `APP_NAME`.

---

# 38.

```bash
pm2 save
```

Saves the current PM2 process list.

This allows the processes to be restored automatically after a server reboot (when PM2 startup is configured).

---

# 39.

```bash
echo "======================================"
echo "Deployment completed successfully!"
echo "======================================"
```

Prints the final success message:

```
======================================
Deployment completed successfully!
======================================
```

---

## Overall deployment flow

```text
Start script
      │
      ▼
Validate required environment variables
      │
      ▼
Go to application directory
      │
      ▼
Clean old build files and caches
      │
      ▼
Fetch latest Git changes (retry once after cleanup if needed)
      │
      ▼
Checkout deployment branch
      │
      ▼
Fast-forward pull from remote
      │
      ▼
Verify .env exists
      │
      ▼
Install dependencies (npm ci)
      │
      ▼
Build the application
      │
      ▼
PM2 process exists?
      │
 ┌────┴─────┐
 │          │
Yes         No
 │          │
Reload      Start
 │          │
 └────┬─────┘
      ▼
Save PM2 process list
      │
      ▼
Deployment complete
```

This script follows several production best practices: it validates required configuration early, cleans up disk space before building, uses `npm ci` for deterministic installs, updates code with `git pull --ff-only` to avoid unexpected merge commits, and manages the application through PM2 with reloads for existing deployments.
