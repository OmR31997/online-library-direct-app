# Online Library - PM2 Edition

This is an interactive software engineering learning roadmap, tutorial, and quiz platform built using Next.js, Prisma (PostgreSQL), and Valkey/Redis.

This edition of the repository is set up specifically for host-level running and deployment using **PM2** instead of Docker.

## Getting Started

First, make sure to read the [Deployment & Operations Guide](file:///d:/Ez_Softech/next-app/online-library-pm2/DEPLOYMENT.md) for full system requirements and setup instructions.

### Local Development

1. **Configure Environment Variables**:
   Copy `.env.example` to `.env` and fill in the PostgreSQL database and Valkey connection details:

   ```bash
   cp .env.example .env
   ```

2. **Install Dependencies**:

   ```bash
   npm install
   ```

3. **Database Setup**:
   Generate the Prisma client and apply migrations:

   ```bash
   npx prisma generate
   npx prisma migrate deploy
   npx prisma db seed
   ```

4. **Run Development Server**:

   ```bash
   npm run dev
   ```

   Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

## Automated PM2 Deployment

To deploy this project to a host environment under PM2 control, run:

```bash
./deploy.sh
```

For domain setups with SSL/TLS, pass your domain name:

```bash
./deploy.sh your-domain.com
```

Refer to [DEPLOYMENT.md](file:///d:/Ez_Softech/next-app/online-library-pm2/DEPLOYMENT.md) for configuring the Nginx reverse proxy.
