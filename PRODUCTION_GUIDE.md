# 🚀 Liam Production Guide - Complete Reference

**All-in-one guide for deploying, securing, and operating Liam in production.**

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Environment Setup](#environment-setup)
3. [Deployment Methods](#deployment-methods)
4. [AI Provider Reliability](#ai-provider-reliability)
5. [Security Hardening](#security-hardening)
6. [Health Monitoring](#health-monitoring)
7. [Backup & Recovery](#backup--recovery)
8. [Production Checklist](#production-checklist)
9. [Troubleshooting](#troubleshooting)

---

## ⚡ Quick Start

### Minimum Requirements
- **Server**: 2+ CPU cores, 4+ GB RAM, 20+ GB disk
- **Database**: PostgreSQL 15+ or Supabase account
- **API Keys**: OpenAI or compatible provider
- **Domain**: (Optional) For production deployment

### 5-Minute Docker Setup

```bash
# 1. Install dependencies
python3 setup_agents.py install

# 2. Configure environment
python3 setup_agents.py configure

# 3. Start services
python3 start.py

# 4. Verify health
curl http://localhost:3001/api/health
```

---

## ⚙️ Environment Setup

### Required Environment Variables

Create `.env.local` with the following:

```bash
# =============================================================================
# Application Settings
# =============================================================================
NEXT_PUBLIC_BASE_URL=http://localhost:3001
NEXT_PUBLIC_ENV_NAME=development
PORT=3001

# =============================================================================
# Database (Supabase)
# =============================================================================
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
POSTGRES_URL=postgresql://USERNAME:PASSWORD@HOSTNAME:5432/DATABASE

# =============================================================================
# AI Model API Keys
# =============================================================================
# Primary provider (required)
OPENAI_API_KEY=sk-...

# Fallback provider (recommended for reliability)
ANTHROPIC_API_KEY=sk-ant-...

# Custom provider (optional - e.g., Z.AI)
# OPENAI_BASE_URL=https://api.z.ai/api/openai
# ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic

# =============================================================================
# AI Reliability Configuration
# =============================================================================
AI_RELIABILITY_ENABLED=true
AI_MAX_RETRIES=3
AI_RETRY_DELAY_MS=1000
AI_CIRCUIT_BREAKER_THRESHOLD=5
AI_CIRCUIT_BREAKER_TIMEOUT_MS=60000

# =============================================================================
# GitHub OAuth (optional)
# =============================================================================
GITHUB_CLIENT_ID=Iv1.xxxxxxxxxxxx
GITHUB_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
LIAM_GITHUB_OAUTH_KEYRING=k2025-01:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Generate keyring with:
# node -e "console.log('k2025-01:' + require('crypto').randomBytes(32).toString('base64'))"

# =============================================================================
# Monitoring (optional)
# =============================================================================
LANGSMITH_API_KEY=ls__xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
LANGSMITH_PROJECT=liam-production
SENTRY_DSN=https://xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx@sentry.io/xxxxxx

# =============================================================================
# Email (optional)
# =============================================================================
RESEND_API_KEY=re_xxxxxxxxxxxxxxxxxxxx
RESEND_EMAIL_FROM_ADDRESS=noreply@yourdomain.com

# =============================================================================
# Production Settings
# =============================================================================
NODE_ENV=production
LOG_LEVEL=info
NEXT_TELEMETRY_DISABLED=1
```

### API Provider Options

**Option 1: Standard OpenAI**
```bash
OPENAI_API_KEY=sk-...
```

**Option 2: OpenAI + Anthropic Fallback** (Recommended)
```bash
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
```

**Option 3: Z.AI (Cost-Effective)**
```bash
OPENAI_API_KEY=your-zai-key
OPENAI_BASE_URL=https://api.z.ai/api/openai
ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
```

**Option 4: Azure OpenAI**
```bash
OPENAI_API_KEY=your-azure-key
OPENAI_BASE_URL=https://your-resource.openai.azure.com/openai/deployments/your-deployment
```

---

## 🐳 Deployment Methods

### Method 1: Docker Compose (Recommended)

**Quick Start:**
```bash
# Start all services
python3 start.py docker

# Or manually:
docker-compose up -d

# With nginx reverse proxy
docker-compose --profile with-nginx up -d

# Full stack (app + db + redis + pgadmin)
docker-compose --profile with-nginx --profile with-redis up -d
```

**Docker Compose Configuration:**

The system includes:
- **App**: Next.js application (3 replicas)
- **PostgreSQL**: Database with health checks
- **Nginx**: Reverse proxy with SSL support
- **Redis**: Caching layer (optional)
- **pgAdmin**: Database management (optional)

**Profiles:**
- `default`: App only
- `with-nginx`: Add nginx reverse proxy
- `with-redis`: Add Redis caching
- `with-pgadmin`: Add database UI

### Method 2: Traditional Deployment

```bash
# 1. Install dependencies
python3 setup_agents.py install

# 2. Build application
pnpm build --filter @liam-hq/app

# 3. Start with PM2
npm install -g pm2
pm2 start pnpm --name "liam" -- start --filter @liam-hq/app
pm2 save
pm2 startup

# 4. Configure nginx
sudo cp nginx.conf /etc/nginx/sites-available/liam
sudo ln -s /etc/nginx/sites-available/liam /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Method 3: Kubernetes

```bash
# 1. Create namespace
kubectl create namespace liam

# 2. Create secrets
kubectl create secret generic liam-secrets \
  --from-literal=postgres-url="postgresql://..." \
  --from-literal=openai-api-key="sk-..." \
  --namespace=liam

# 3. Deploy application
python3 start.py kubernetes

# 4. Verify deployment
kubectl get pods --namespace=liam
```

### Method 4: Cloud Platforms

**AWS (ECS Fargate):**
```bash
# Build and push image
docker build -t liam:latest .
docker tag liam:latest your-ecr-repo/liam:latest
docker push your-ecr-repo/liam:latest

# Deploy via ECS console or AWS CLI
python3 start.py aws
```

**Google Cloud Run:**
```bash
# Build and deploy
gcloud builds submit --tag gcr.io/your-project/liam
python3 start.py gcp
```

**Heroku:**
```bash
# Create app and deploy
heroku create liam-app
heroku addons:create heroku-postgresql:standard-0
git push heroku main
```

---

## 🤖 AI Provider Reliability

### Overview

Liam includes production-grade AI reliability features:
- **Provider Fallback**: OpenAI → Anthropic automatic switching
- **Exponential Backoff**: Smart retry with jitter
- **Circuit Breaker**: Fail-fast during outages
- **Error Classification**: Intelligent error handling
- **Metrics Tracking**: Real-time monitoring

### Configuration

**Basic Setup (Single Provider):**
```typescript
import { ChatOpenAI } from '@langchain/openai'

const model = new ChatOpenAI({
  model: 'gpt-4',
  streaming: true,
})
```

**Resilient Setup (With Fallback):**
```typescript
import { createResilientChatModel } from './ai-reliability'

const model = createResilientChatModel({
  primary: {
    provider: 'openai',
    model: 'gpt-4',
    timeout: 30000,
  },
  fallback: {
    provider: 'anthropic',
    model: 'claude-3-sonnet-20240229',
    timeout: 30000,
  },
  enableCircuitBreaker: true,
  enableRetry: true,
  enableLogging: process.env['NODE_ENV'] === 'development',
})
```

### Error Handling Strategy

**Rate Limits (429):**
- ✅ Immediate fallback to secondary provider
- ✅ Circuit breaker NOT opened
- ✅ No retry attempts (waste of quota)

**Timeouts:**
- ✅ Retry with exponential backoff: 1s, 2s, 4s
- ✅ Include ±25% jitter to prevent thundering herd
- ✅ Max 3 retry attempts

**Auth Errors (401/403):**
- ❌ No retry (fail fast)
- ❌ Alert operator immediately
- ❌ Check API key configuration

**Invalid Requests (400/422):**
- ❌ No retry (fix the request)
- ❌ Log error for debugging
- ❌ Return error to user

**Server Errors (500/502/503/504):**
- ✅ Retry with backoff
- ✅ Try fallback if retries exhausted
- ✅ Increment circuit breaker failure count

### Circuit Breaker

**States:**
- **CLOSED**: Normal operation
- **OPEN**: Too many failures, fail fast
- **HALF_OPEN**: Testing recovery

**Transitions:**
```
CLOSED --[5 failures]--> OPEN
OPEN --[60s timeout]--> HALF_OPEN
HALF_OPEN --[success]--> CLOSED
HALF_OPEN --[failure]--> OPEN
```

**Reset Manually:**
```bash
curl -X POST http://localhost:3001/api/admin/reset-circuit-breakers
```

### Monitoring

**Metrics Endpoint:**
```bash
curl http://localhost:3001/api/metrics

# Response includes:
{
  "ai_providers": {
    "primary": {
      "provider": "openai",
      "total_requests": 150,
      "successful_requests": 148,
      "failed_requests": 2,
      "success_rate": "98.67%",
      "avg_latency_ms": 2340
    },
    "fallback": {
      "provider": "anthropic",
      "total_requests": 2,
      "successful_requests": 2,
      "success_rate": "100.00%"
    },
    "circuit_breakers": {
      "primary": { "state": "CLOSED", "failureCount": 0 },
      "fallback": { "state": "CLOSED", "failureCount": 0 }
    }
  }
}
```

**Alerting Rules:**
1. Success rate < 95% → Investigate
2. Circuit breaker OPEN → Page on-call
3. Avg latency > 5s → Performance issue
4. Fallback usage > 5% → Primary provider degraded

---

## 🔒 Security Hardening

### Pre-Deployment Security

**1. Firewall Configuration**
```bash
# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Restrict SSH (replace X.X.X.X with your IP)
sudo ufw allow from X.X.X.X to any port 22

# Database port (internal only)
sudo ufw deny 5432/tcp

# Enable firewall
sudo ufw enable
```

**2. Secure File Permissions**
```bash
# Environment file
chmod 600 .env.local

# Scripts
chmod 700 setup_agents.py start.py

# Application files
chmod -R 755 /opt/liam
```

**3. Non-Root User**
```bash
# Create dedicated user
sudo useradd -r -s /bin/bash -d /opt/liam liam

# Set ownership
sudo chown -R liam:liam /opt/liam

# Run as liam user
sudo -u liam python3 start.py
```

### SSL/TLS Setup

**Using Let's Encrypt:**
```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d liam.yourdomain.com

# Auto-renewal test
sudo certbot renew --dry-run
```

**Using Custom Certificate:**
```bash
# Copy certificates
sudo mkdir -p /etc/nginx/ssl
sudo cp your-cert.crt /etc/nginx/ssl/
sudo cp your-key.key /etc/nginx/ssl/

# Update nginx config
sudo nano /etc/nginx/sites-available/liam
# Add:
ssl_certificate /etc/nginx/ssl/your-cert.crt;
ssl_certificate_key /etc/nginx/ssl/your-key.key;
```

### Security Headers

Add to nginx configuration:
```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

### Secrets Management

**DO NOT:**
- ❌ Commit `.env.local` to version control
- ❌ Share API keys in Slack/email
- ❌ Use production keys in development
- ❌ Hardcode secrets in code

**DO:**
- ✅ Use environment variables
- ✅ Rotate keys every 90 days
- ✅ Use different keys per environment
- ✅ Enable MFA on all accounts
- ✅ Use secrets manager (AWS Secrets Manager, etc.)

### API Key Rotation

**Automated Script:**
```bash
# Rotate OpenAI key
python3 setup_agents.py rotate-keys --provider openai

# Rotate all keys
python3 setup_agents.py rotate-keys --all
```

**Manual Process:**
1. Generate new API key
2. Update `.env.local` with new key
3. Test with health check
4. Restart application
5. Revoke old key after 24 hours

---

## 📊 Health Monitoring

### Health Check Endpoints

**1. Liveness Probe** (`/api/health`)
```bash
curl http://localhost:3001/api/health

# Response:
{
  "status": "ok",
  "timestamp": "2025-01-08T19:00:00.000Z",
  "uptime": 3600,
  "version": "1.0.0"
}
```

**2. Readiness Probe** (`/api/ready`)
```bash
curl http://localhost:3001/api/ready

# Response:
{
  "status": "ok",
  "database": "connected",
  "dependencies": {
    "supabase": "healthy",
    "openai": "healthy"
  },
  "requiredEnvVars": ["OPENAI_API_KEY", "POSTGRES_URL"]
}
```

**3. Metrics Endpoint** (`/api/metrics`)
```bash
curl http://localhost:3001/api/metrics

# Response includes:
{
  "memory": { "used": "120 MB", "total": "1024 MB" },
  "uptime": "2 hours 15 minutes",
  "requests": { "total": 1500, "success": 1485 },
  "ai_providers": { /* See AI Reliability section */ }
}
```

### Docker Health Checks

**Dockerfile:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3001/api/health || exit 1
```

**docker-compose.yml:**
```yaml
services:
  app:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

### Kubernetes Health Checks

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: liam
    livenessProbe:
      httpGet:
        path: /api/health
        port: 3001
      initialDelaySeconds: 30
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /api/ready
        port: 3001
      initialDelaySeconds: 10
      periodSeconds: 5
```

### Monitoring Dashboard

**Setup with monitoring script:**
```bash
# Create monitoring script
python3 start.py monitor --interval 60

# Output:
[2025-01-08 19:00:00] ✅ Health: OK | Memory: 120MB | Requests: 1500
[2025-01-08 19:01:00] ✅ Health: OK | Memory: 125MB | Requests: 1650
[2025-01-08 19:02:00] ⚠️  Health: WARN | Memory: 900MB | Requests: 1800
```

### Alerting

**Set up alerts for:**
1. Health check failures (3+ consecutive)
2. Memory usage > 80%
3. Request error rate > 10%
4. AI provider circuit breaker OPEN
5. Database connection failures

**Example alert script:**
```bash
#!/bin/bash
HEALTH=$(curl -s http://localhost:3001/api/health | jq -r '.status')
if [ "$HEALTH" != "ok" ]; then
  # Send alert (email, Slack, PagerDuty, etc.)
  echo "ALERT: Liam health check failed!" | mail -s "Liam Alert" ops@company.com
fi
```

---

## 💾 Backup & Recovery

### Automated Backups

**Configure backup:**
```bash
# Setup automated backups (runs daily at 2 AM)
python3 setup_agents.py backup configure \
  --schedule "0 2 * * *" \
  --retention 30 \
  --compress \
  --s3-bucket liam-backups

# Test backup
python3 setup_agents.py backup test
```

**Backup Features:**
- ✅ Automated scheduling via cron
- ✅ Compression (gzip)
- ✅ Retention policy (default: 30 days)
- ✅ S3 upload support
- ✅ GPG encryption
- ✅ Email notifications

### Manual Backup

```bash
# Quick backup
python3 setup_agents.py backup now

# Backup with custom name
python3 setup_agents.py backup now --name "pre-migration-backup"

# Backup to S3
python3 setup_agents.py backup now --s3-bucket liam-backups
```

### Restore Procedure

**1. List available backups:**
```bash
python3 setup_agents.py backup list

# Output:
Available backups:
- backup-2025-01-08-02-00.sql.gz (2.5 GB)
- backup-2025-01-07-02-00.sql.gz (2.4 GB)
- backup-2025-01-06-02-00.sql.gz (2.3 GB)
```

**2. Restore from backup:**
```bash
# Dry run (verify without restoring)
python3 setup_agents.py restore --file backups/backup-2025-01-08-02-00.sql.gz --dry-run

# Actual restore
python3 setup_agents.py restore --file backups/backup-2025-01-08-02-00.sql.gz

# Restore from S3
python3 setup_agents.py restore --s3-key backup-2025-01-08-02-00.sql.gz
```

**3. Verify restore:**
```bash
# Check database
psql "$POSTGRES_URL" -c "SELECT COUNT(*) FROM users;"

# Verify application
curl http://localhost:3001/api/ready
```

### Disaster Recovery

**RTO (Recovery Time Objective):** 15 minutes
**RPO (Recovery Point Objective):** 24 hours (daily backups)

**Recovery Steps:**
1. Provision new infrastructure
2. Install dependencies: `python3 setup_agents.py install`
3. Configure environment: `python3 setup_agents.py configure`
4. Restore database: `python3 setup_agents.py restore --file latest.sql.gz`
5. Start application: `python3 start.py`
6. Verify health: `curl http://localhost:3001/api/health`

**Time Estimates:**
- Infrastructure provisioning: 5 minutes
- Dependency installation: 3 minutes
- Database restore: 5 minutes
- Application startup: 2 minutes
- **Total: ~15 minutes**

---

## ✅ Production Checklist

### Pre-Deployment

**Infrastructure:**
- [ ] Server provisioned (2+ CPU, 4+ GB RAM)
- [ ] Database created (PostgreSQL 15+ or Supabase)
- [ ] Domain configured (DNS pointing to server)
- [ ] SSL certificate obtained
- [ ] Firewall rules configured

**Security:**
- [ ] `.env.local` created and secured (chmod 600)
- [ ] API keys rotated (separate dev/prod keys)
- [ ] Non-root user created
- [ ] SSH hardened (key-only auth)
- [ ] Security headers configured

**Configuration:**
- [ ] Environment variables validated
- [ ] OAuth keyring generated
- [ ] Backup schedule configured
- [ ] Monitoring alerts set up

### Deployment

**Build & Deploy:**
- [ ] Dependencies installed
- [ ] Application built successfully
- [ ] Docker images created (if using Docker)
- [ ] Services started
- [ ] Health checks passing

**Verification:**
- [ ] `/api/health` returns 200 OK
- [ ] `/api/ready` shows database connected
- [ ] `/api/metrics` returns data
- [ ] Test schema generation works
- [ ] GitHub OAuth works (if enabled)

### Post-Deployment

**Monitoring:**
- [ ] Health check monitoring active
- [ ] Metrics dashboard configured
- [ ] Alert rules created
- [ ] Log aggregation set up

**Backup:**
- [ ] First backup completed
- [ ] Backup restoration tested
- [ ] S3 upload verified (if using)
- [ ] Retention policy working

**Documentation:**
- [ ] Deployment notes created
- [ ] Access credentials documented (securely)
- [ ] Runbooks created
- [ ] Emergency contacts listed

---

## 🔧 Troubleshooting

### Application Won't Start

**Check logs:**
```bash
# Docker
docker-compose logs app

# PM2
pm2 logs liam

# Systemd
journalctl -u liam -f
```

**Common issues:**
- Missing environment variables → Check `.env.local`
- Database connection failed → Verify `POSTGRES_URL`
- Port already in use → Stop conflicting process or change port
- Permission denied → Check file permissions and user

### Health Check Failing

**Debug steps:**
```bash
# 1. Check if service is running
curl -v http://localhost:3001/api/health

# 2. Check database connectivity
psql "$POSTGRES_URL" -c "SELECT 1;"

# 3. Check environment
python3 setup_agents.py validate-env

# 4. Check logs for errors
tail -f /var/log/liam/error.log
```

### High Memory Usage

**Identify cause:**
```bash
# Check metrics
curl http://localhost:3001/api/metrics | jq '.memory'

# Docker stats
docker stats

# Process memory
ps aux | grep node
```

**Solutions:**
- Limit memory in docker-compose: `mem_limit: 1g`
- Increase swap space
- Scale horizontally (add more instances)
- Optimize AI model usage (use smaller models)

### Slow Performance

**Diagnose:**
```bash
# Check latency
curl http://localhost:3001/api/metrics | jq '.ai_providers.primary.avg_latency_ms'

# Check database queries
# Enable slow query log in PostgreSQL

# Profile application
NODE_ENV=production node --prof server.js
```

**Solutions:**
- Switch to faster AI model (GPT-3.5-turbo instead of GPT-4)
- Add database indexes
- Enable caching (Redis)
- Use CDN for static assets

### Database Issues

**Connection pool exhausted:**
```bash
# Increase pool size in connection string
POSTGRES_URL="postgresql://...?pool_max=20"

# Or scale app instances
docker-compose up -d --scale app=3
```

**Slow queries:**
```sql
-- Find slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### AI Provider Issues

**Rate limit errors:**
- Check quota in provider dashboard
- Switch to fallback provider temporarily
- Upgrade plan or request quota increase
- Implement request queuing

**Timeout errors:**
- Increase timeout in config (30s → 60s)
- Switch to faster model
- Check network latency to provider

**Circuit breaker stuck OPEN:**
```bash
# Reset circuit breaker
curl -X POST http://localhost:3001/api/admin/reset-circuit-breakers

# Or restart application
python3 start.py restart
```

---

## 📚 Quick Reference

### Essential Commands

```bash
# Setup
python3 setup_agents.py install              # Install dependencies
python3 setup_agents.py configure            # Configure environment
python3 setup_agents.py validate-env         # Validate configuration

# Deployment
python3 start.py                             # Start application
python3 start.py docker                      # Start with Docker
python3 start.py stop                        # Stop application
python3 start.py restart                     # Restart application

# Backup
python3 setup_agents.py backup now           # Manual backup
python3 setup_agents.py backup list          # List backups
python3 setup_agents.py restore --file X     # Restore backup

# Monitoring
python3 start.py monitor                     # Start monitoring
curl http://localhost:3001/api/health        # Health check
curl http://localhost:3001/api/metrics       # Get metrics

# Troubleshooting
python3 start.py logs                        # View logs
python3 start.py debug                       # Debug mode
python3 setup_agents.py doctor               # System diagnostics
```

### Important URLs

- **Application**: `http://localhost:3001`
- **Health Check**: `http://localhost:3001/api/health`
- **Metrics**: `http://localhost:3001/api/metrics`
- **Documentation**: `http://localhost:3001/docs`

### Support Resources

- **GitHub Issues**: https://github.com/Zeeeepa/liam/issues
- **Documentation**: https://github.com/Zeeeepa/liam/tree/main/docs
- **Community**: https://github.com/Zeeeepa/liam/discussions

---

**Last Updated**: 2025-01-08
**Version**: 1.0.0
**Status**: Production Ready ✅
