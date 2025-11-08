# 🚀 Liam Production Deployment Guide

Complete guide for deploying Liam to production environments.

---

## 📋 Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Deployment Methods](#deployment-methods)
3. [Docker Deployment](#docker-deployment)
4. [Traditional Deployment](#traditional-deployment)
5. [Kubernetes Deployment](#kubernetes-deployment)
6. [Cloud Platform Deployment](#cloud-platform-deployment)
7. [Post-Deployment](#post-deployment)
8. [Monitoring & Maintenance](#monitoring--maintenance)
9. [Troubleshooting](#troubleshooting)

---

## ✅ Pre-Deployment Checklist

### Infrastructure Requirements

- [ ] **Server/VM**: 2+ CPU cores, 4+ GB RAM, 20+ GB disk
- [ ] **Database**: PostgreSQL 15+ with 10+ GB storage
- [ ] **Domain**: DNS configured and pointing to server
- [ ] **SSL Certificate**: Let's Encrypt or custom certificate
- [ ] **Backup Storage**: S3 bucket or equivalent

### API Keys & Credentials

- [ ] **OpenAI API Key** or alternative LLM provider
- [ ] **Supabase Project** created with database
- [ ] **GitHub OAuth App** (if using GitHub integration)
- [ ] **Email Service** (Resend or SMTP)
- [ ] **Monitoring** (Sentry, optional)

### Security Preparation

- [ ] Review [ACTIONS/SECURITY.md](ACTIONS/SECURITY.md)
- [ ] Generate strong passwords for database
- [ ] Create OAuth encryption keyring
- [ ] Configure firewall rules
- [ ] Set up SSL/TLS certificates
- [ ] Plan secret rotation schedule

### Backup Strategy

- [ ] Configure automated backups (see [backup.sh](ACTIONS/backup.sh))
- [ ] Test backup restoration
- [ ] Set up off-site backup storage (S3)
- [ ] Document recovery procedures

---

## 🎯 Deployment Methods

### Method Comparison

| Method | Complexity | Scalability | Best For |
|--------|-----------|-------------|----------|
| Docker Compose | Low | Medium | Small teams, single server |
| Traditional | Medium | Low | Simple setups, full control |
| Kubernetes | High | High | Enterprise, auto-scaling |
| Cloud Platform | Medium | High | Managed services, quick start |

---

## 🐳 Docker Deployment

### Quick Start (Recommended)

```bash
# 1. Clone repository
git clone https://github.com/Zeeeepa/liam.git
cd liam

# 2. Create environment file
cp .env.example .env.local
# Edit .env.local with your values

# 3. Build and start
docker-compose up -d

# 4. Verify health
curl http://localhost:3001/api/health
```

### With Nginx (Load Balancer)

```bash
# Start with nginx reverse proxy
docker-compose --profile with-nginx up -d

# Configure SSL certificates
sudo mkdir -p ssl
sudo cp your-cert.crt ssl/
sudo cp your-key.key ssl/
```

### Full Stack (App + DB + Cache + Monitoring)

```bash
# Start all services
docker-compose --profile with-nginx --profile with-redis --profile with-pgadmin up -d

# Access services:
# - App: http://localhost:3001
# - pgAdmin: http://localhost:5050
# - Nginx: http://localhost (or https with SSL)
```

### Production Configuration

**Edit docker-compose.yml**:

```yaml
services:
  app:
    environment:
      - NODE_ENV=production
      - NEXT_PUBLIC_BASE_URL=https://liam.yourdomain.com
    deploy:
      replicas: 3  # Scale to 3 instances
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

### Docker Swarm (Multi-Server)

```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.yml liam

# Scale services
docker service scale liam_app=5

# Monitor
docker service ls
docker service logs liam_app
```

---

## 🖥️ Traditional Deployment

### Ubuntu/Debian Server

```bash
# 1. Run setup script
./ACTIONS/setup.sh

# 2. Configure environment
cp .env.example .env.local
# Edit .env.local

# 3. Build application
pnpm build --filter @liam-hq/app

# 4. Start with PM2 (recommended)
npm install -g pm2
pm2 start pnpm --name "liam" -- start --filter @liam-hq/app
pm2 save
pm2 startup

# 5. Configure nginx
sudo cp ACTIONS/examples/nginx-loadbalancer.conf /etc/nginx/sites-available/liam
sudo ln -s /etc/nginx/sites-available/liam /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Systemd Service

Create `/etc/systemd/system/liam.service`:

```ini
[Unit]
Description=Liam AI Schema Designer
After=network.target postgresql.service

[Service]
Type=simple
User=liam
WorkingDirectory=/opt/liam
Environment="NODE_ENV=production"
EnvironmentFile=/opt/liam/.env.local
ExecStart=/usr/bin/pnpm start --filter @liam-hq/app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable liam
sudo systemctl start liam
sudo systemctl status liam
```

---

## ☸️ Kubernetes Deployment

### Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- Ingress controller installed

### Quick Deploy

```bash
# 1. Create namespace
kubectl create namespace liam

# 2. Create secrets
kubectl create secret generic liam-secrets \
  --from-literal=postgres-url="postgresql://..." \
  --from-literal=openai-api-key="sk-..." \
  --namespace=liam

# 3. Apply manifests
kubectl apply -f k8s/ --namespace=liam

# 4. Verify deployment
kubectl get pods --namespace=liam
kubectl get services --namespace=liam
```

### Sample Deployment Manifest

Create `k8s/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: liam-app
  namespace: liam
spec:
  replicas: 3
  selector:
    matchLabels:
      app: liam
  template:
    metadata:
      labels:
        app: liam
    spec:
      containers:
      - name: liam
        image: liam:latest
        ports:
        - containerPort: 3001
        env:
        - name: NODE_ENV
          value: "production"
        - name: POSTGRES_URL
          valueFrom:
            secretKeyRef:
              name: liam-secrets
              key: postgres-url
        - name: OPENAI_API_KEY
          valueFrom:
            secretKeyRef:
              name: liam-secrets
              key: openai-api-key
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
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: liam-service
  namespace: liam
spec:
  selector:
    app: liam
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3001
  type: LoadBalancer
```

### Ingress Configuration

Create `k8s/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: liam-ingress
  namespace: liam
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - liam.yourdomain.com
    secretName: liam-tls
  rules:
  - host: liam.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: liam-service
            port:
              number: 80
```

---

## ☁️ Cloud Platform Deployment

### AWS (Elastic Beanstalk)

```bash
# 1. Install EB CLI
pip install awsebcli

# 2. Initialize application
eb init -p docker liam-app --region us-east-1

# 3. Create environment
eb create liam-production

# 4. Deploy
eb deploy

# 5. Open application
eb open
```

### AWS (ECS Fargate)

```bash
# 1. Build and push image
docker build -t liam:latest .
docker tag liam:latest your-ecr-repo/liam:latest
docker push your-ecr-repo/liam:latest

# 2. Create task definition (see ECS console)
# 3. Create service with load balancer
# 4. Configure auto-scaling
```

### Google Cloud Run

```bash
# 1. Build image
gcloud builds submit --tag gcr.io/your-project/liam

# 2. Deploy
gcloud run deploy liam \
  --image gcr.io/your-project/liam \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars NODE_ENV=production

# 3. Get URL
gcloud run services describe liam --region us-central1
```

### Heroku

```bash
# 1. Create app
heroku create liam-app

# 2. Add PostgreSQL
heroku addons:create heroku-postgresql:standard-0

# 3. Set environment variables
heroku config:set OPENAI_API_KEY=sk-...
heroku config:set NODE_ENV=production

# 4. Deploy
git push heroku main

# 5. Open
heroku open
```

### Vercel (Serverless)

```bash
# 1. Install Vercel CLI
npm i -g vercel

# 2. Login
vercel login

# 3. Deploy
vercel --prod

# Note: May need serverless PostgreSQL (e.g., Neon, PlanetScale)
```

---

## 🔧 Post-Deployment

### Verify Deployment

```bash
# 1. Health check
curl https://liam.yourdomain.com/api/health

# 2. Readiness check
curl https://liam.yourdomain.com/api/ready

# 3. Metrics
curl https://liam.yourdomain.com/api/metrics

# 4. Test schema generation
# Open https://liam.yourdomain.com
# Try: "Create a users table"
```

### Configure Automated Backups

```bash
# 1. Test backup script
./ACTIONS/backup.sh --dry-run

# 2. Add to crontab
crontab -e
# Add: 0 2 * * * /path/to/liam/ACTIONS/backup.sh --compress --s3-bucket liam-backups

# 3. Test restoration
./ACTIONS/restore.sh --file backups/latest.sql.gz --dry-run
```

### Set Up Monitoring

**Sentry Integration**:

```bash
# Add to .env.local
SENTRY_DSN=https://xxxxx@sentry.io/xxxxx
```

**Health Check Monitoring**:

```bash
# Create monitoring script
cat > /usr/local/bin/monitor-liam.sh << 'EOF'
#!/bin/bash
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" https://liam.yourdomain.com/api/health)
if [ "$HEALTH" != "200" ]; then
  echo "Liam health check failed: $HEALTH"
  # Send alert (email, Slack, etc.)
fi
EOF

# Add to crontab (check every 5 minutes)
*/5 * * * * /usr/local/bin/monitor-liam.sh
```

### SSL Certificate Setup

```bash
# Using Let's Encrypt
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d liam.yourdomain.com

# Auto-renewal test
sudo certbot renew --dry-run
```

---

## 📊 Monitoring & Maintenance

### Daily Checks

- [ ] Check application health (`/api/health`)
- [ ] Review error logs
- [ ] Verify backup completion
- [ ] Monitor disk space

### Weekly Maintenance

- [ ] Review metrics (`/api/metrics`)
- [ ] Check database performance
- [ ] Test backup restoration
- [ ] Update dependencies (security patches)

### Monthly Tasks

- [ ] Review security logs
- [ ] Rotate API keys (if policy requires)
- [ ] Performance optimization review
- [ ] Capacity planning assessment

### Quarterly Reviews

- [ ] Security audit (see [SECURITY.md](ACTIONS/SECURITY.md))
- [ ] Disaster recovery drill
- [ ] Cost optimization review
- [ ] Architecture review

---

## 🔍 Troubleshooting

### Application Won't Start

```bash
# Check logs
docker-compose logs app
# or
journalctl -u liam -n 100

# Verify environment
cat .env.local | grep REQUIRED

# Test database connection
psql "$POSTGRES_URL" -c "SELECT 1;"
```

### Health Check Failing

```bash
# Check app status
curl -v http://localhost:3001/api/health

# Check database connectivity
curl -v http://localhost:3001/api/ready

# Review logs for errors
tail -f /var/log/liam/error.log
```

### High Memory Usage

```bash
# Check container stats
docker stats

# Limit memory in docker-compose.yml
services:
  app:
    deploy:
      resources:
        limits:
          memory: 1G
```

### Slow Performance

```bash
# Check metrics
curl http://localhost:3001/api/metrics

# Monitor database queries
# Enable slow query log in PostgreSQL

# Add database indexes if needed
# Review agent execution times in logs
```

### Database Connection Pool Exhausted

```bash
# Increase connection limit in .env.local
# POSTGRES_URL=...?pool_max=20

# Or scale horizontally with more app instances
docker-compose up -d --scale app=3
```

---

## 📚 Additional Resources

- [Setup Instructions](ACTIONS/INSTRUCTIONS.md)
- [Security Guide](ACTIONS/SECURITY.md)
- [Backup & Restore](ACTIONS/backup.sh)
- [Docker Health Checks](ACTIONS/examples/docker-healthcheck.yml)
- [Nginx Configuration](ACTIONS/examples/nginx-loadbalancer.conf)

---

## 🆘 Support

- **Issues**: https://github.com/Zeeeepa/liam/issues
- **Discussions**: https://github.com/Zeeeepa/liam/discussions
- **Documentation**: https://github.com/Zeeeepa/liam/tree/main/ACTIONS

---

**Ready to deploy? Start with the [Pre-Deployment Checklist](#pre-deployment-checklist)! 🚀**

