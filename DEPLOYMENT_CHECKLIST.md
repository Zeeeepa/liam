# ✅ Liam Production Deployment Checklist

Use this checklist to ensure a smooth, secure deployment to production.

---

## 📋 Pre-Deployment

### Infrastructure Setup

- [ ] **Server Provisioned**
  - [ ] 2+ CPU cores
  - [ ] 4+ GB RAM
  - [ ] 20+ GB disk space
  - [ ] Ubuntu 22.04+ or Debian 11+

- [ ] **Database Ready**
  - [ ] PostgreSQL 15+ installed or Supabase project created
  - [ ] Database accessible from application server
  - [ ] Connection string tested
  - [ ] Backup storage configured (S3 or equivalent)

- [ ] **Domain & DNS**
  - [ ] Domain name registered
  - [ ] DNS A record pointing to server IP
  - [ ] TTL reduced (for quick updates if needed)

- [ ] **SSL Certificate**
  - [ ] Certificate obtained (Let's Encrypt or commercial)
  - [ ] Certificate files accessible
  - [ ] Auto-renewal configured

### Security Preparation

- [ ] **Firewall Configuration**
  - [ ] Port 80 (HTTP) open
  - [ ] Port 443 (HTTPS) open
  - [ ] Port 22 (SSH) restricted to admin IPs
  - [ ] Database port restricted to application only
  - [ ] All other ports closed

- [ ] **User Management**
  - [ ] Non-root user created for application
  - [ ] SSH key authentication configured
  - [ ] Password authentication disabled
  - [ ] sudo access configured

- [ ] **Security Review**
  - [ ] Read [ACTIONS/SECURITY.md](ACTIONS/SECURITY.md)
  - [ ] All security recommendations noted
  - [ ] Security audit scheduled

### API Keys & Credentials

- [ ] **Required Keys Obtained**
  - [ ] OpenAI API key (or alternative)
  - [ ] Supabase project URL
  - [ ] Supabase anon key
  - [ ] Supabase service role key
  - [ ] Database connection string

- [ ] **Optional Keys** (if using features)
  - [ ] GitHub OAuth client ID & secret
  - [ ] Anthropic API key
  - [ ] LangSmith API key
  - [ ] Sentry DSN
  - [ ] Resend API key
  - [ ] AWS S3 credentials (for backups)

- [ ] **Key Security**
  - [ ] All keys stored securely (not in code)
  - [ ] .env.local file created and secured (chmod 600)
  - [ ] .env.local added to .gitignore
  - [ ] Key rotation schedule documented

---

## 🚀 Deployment

### Code Preparation

- [ ] **Repository Cloned**
  ```bash
  git clone https://github.com/Zeeeepa/liam.git
  cd liam
  ```

- [ ] **Dependencies Installed**
  ```bash
  ./ACTIONS/setup.sh
  ```

- [ ] **Environment Configured**
  ```bash
  cp .env.example .env.local
  # Edit .env.local with production values
  ```

- [ ] **OAuth Keyring Generated**
  ```bash
  node -e "console.log('k2025-01:' + require('crypto').randomBytes(32).toString('base64'))"
  # Add to .env.local as LIAM_GITHUB_OAUTH_KEYRING
  ```

### Application Build

- [ ] **Production Build Created**
  ```bash
  pnpm build --filter @liam-hq/app
  ```

- [ ] **Build Successful**
  - [ ] No TypeScript errors
  - [ ] No build warnings
  - [ ] Output files generated

### Deployment Method

#### Option A: Docker Deployment

- [ ] **Docker Installed**
  ```bash
  docker --version
  docker-compose --version
  ```

- [ ] **Images Built**
  ```bash
  docker-compose build
  ```

- [ ] **Services Started**
  ```bash
  docker-compose up -d
  ```

- [ ] **Containers Running**
  ```bash
  docker-compose ps
  ```

#### Option B: Traditional Deployment

- [ ] **PM2 Installed**
  ```bash
  npm install -g pm2
  ```

- [ ] **Application Started**
  ```bash
  pm2 start pnpm --name "liam" -- start --filter @liam-hq/app
  pm2 save
  pm2 startup
  ```

- [ ] **Systemd Service Created** (optional)
  - [ ] Service file created
  - [ ] Service enabled
  - [ ] Service started

### Reverse Proxy Setup

- [ ] **Nginx Installed**
  ```bash
  sudo apt install nginx
  ```

- [ ] **Configuration Deployed**
  ```bash
  sudo cp ACTIONS/examples/nginx-loadbalancer.conf /etc/nginx/sites-available/liam
  sudo ln -s /etc/nginx/sites-available/liam /etc/nginx/sites-enabled/
  ```

- [ ] **Configuration Tested**
  ```bash
  sudo nginx -t
  ```

- [ ] **Nginx Reloaded**
  ```bash
  sudo systemctl reload nginx
  ```

---

## ✅ Post-Deployment Verification

### Health Checks

- [ ] **Liveness Check**
  ```bash
  curl https://liam.yourdomain.com/api/health
  # Expected: {"status":"ok",...}
  ```

- [ ] **Readiness Check**
  ```bash
  curl https://liam.yourdomain.com/api/ready
  # Expected: {"status":"ok","database":"connected",...}
  ```

- [ ] **Metrics Available**
  ```bash
  curl https://liam.yourdomain.com/api/metrics
  # Expected: {memory, uptime, etc.}
  ```

### Functional Testing

- [ ] **Web Interface Loads**
  - [ ] Open https://liam.yourdomain.com
  - [ ] Page loads without errors
  - [ ] No console errors

- [ ] **Schema Generation Works**
  - [ ] Enter prompt: "Create a users table"
  - [ ] Agents execute successfully
  - [ ] Schema generated and visible
  - [ ] SQL downloadable

- [ ] **GitHub OAuth** (if enabled)
  - [ ] Login with GitHub works
  - [ ] Repository access works
  - [ ] OAuth flow completes

### Performance Testing

- [ ] **Response Time Acceptable**
  - [ ] Homepage loads < 3s
  - [ ] Health endpoint < 500ms
  - [ ] Schema generation < 60s

- [ ] **Memory Usage Normal**
  ```bash
  docker stats  # or top/htop
  # App memory < 1GB
  ```

- [ ] **No Memory Leaks**
  - [ ] Monitor over 1 hour
  - [ ] Memory stays stable

---

## 🔒 Security Verification

### SSL/TLS

- [ ] **HTTPS Working**
  - [ ] Site loads over HTTPS
  - [ ] Certificate valid
  - [ ] No mixed content warnings

- [ ] **HTTP Redirects to HTTPS**
  ```bash
  curl -I http://liam.yourdomain.com
  # Expected: 301 redirect to https://
  ```

- [ ] **SSL Score Acceptable**
  - [ ] Test at https://www.ssllabs.com/ssltest/
  - [ ] Grade A or A+ preferred

### Security Headers

- [ ] **Security Headers Present**
  ```bash
  curl -I https://liam.yourdomain.com
  ```
  - [ ] `Strict-Transport-Security` header
  - [ ] `X-Frame-Options: SAMEORIGIN`
  - [ ] `X-Content-Type-Options: nosniff`
  - [ ] `X-XSS-Protection: 1; mode=block`

### Access Control

- [ ] **Admin Endpoints Protected**
  - [ ] Metrics endpoint restricted (or acceptable if public)
  - [ ] Database admin tools not publicly accessible
  - [ ] SSH access restricted to admin IPs

- [ ] **Secrets Secure**
  - [ ] .env.local file permissions: 600
  - [ ] No secrets in logs
  - [ ] No secrets exposed in client-side code

---

## 💾 Backup Configuration

### Automated Backups

- [ ] **Backup Script Tested**
  ```bash
  ./ACTIONS/backup.sh --dry-run
  ```

- [ ] **Cron Job Scheduled**
  ```bash
  crontab -e
  # Add: 0 2 * * * /path/to/liam/ACTIONS/backup.sh --compress --retention 30
  ```

- [ ] **S3 Integration** (if using)
  - [ ] AWS CLI configured
  - [ ] S3 bucket created
  - [ ] Upload tested
  - [ ] Lifecycle policy set

- [ ] **GitHub Actions Backup** (optional)
  - [ ] Workflow enabled
  - [ ] Secrets configured
  - [ ] First run successful

### Backup Verification

- [ ] **Backup Created Successfully**
  ```bash
  ls -lh backups/
  ```

- [ ] **Restore Tested**
  ```bash
  ./ACTIONS/restore.sh --file backups/latest.sql.gz --dry-run
  ```

- [ ] **Recovery Procedure Documented**
  - [ ] Restore steps written down
  - [ ] Emergency contacts listed
  - [ ] RTO/RPO defined

---

## 📊 Monitoring Setup

### Application Monitoring

- [ ] **Sentry Configured** (optional)
  - [ ] SENTRY_DSN in .env.local
  - [ ] Error tracking verified
  - [ ] Alert rules configured

- [ ] **LangSmith Configured** (optional)
  - [ ] LANGSMITH_API_KEY in .env.local
  - [ ] Tracing enabled
  - [ ] Traces visible in dashboard

### Health Check Monitoring

- [ ] **External Monitor Configured**
  - [ ] UptimeRobot or equivalent
  - [ ] Check /api/health every 5 minutes
  - [ ] Alert on downtime

- [ ] **Custom Monitoring Script**
  ```bash
  # Create /usr/local/bin/monitor-liam.sh
  # Add to crontab: */5 * * * *
  ```

### Log Monitoring

- [ ] **Logs Accessible**
  ```bash
  # Docker: docker-compose logs -f
  # PM2: pm2 logs liam
  # Systemd: journalctl -u liam -f
  ```

- [ ] **Log Rotation Configured**
  - [ ] Logs don't grow indefinitely
  - [ ] Old logs archived or deleted

---

## 📚 Documentation

### Deployment Documentation

- [ ] **Deployment Notes Created**
  - [ ] Server details recorded
  - [ ] Deployment date noted
  - [ ] Configuration choices documented

- [ ] **Access Information Documented**
  - [ ] Server SSH details
  - [ ] Database credentials (stored securely)
  - [ ] Admin accounts
  - [ ] Emergency contacts

### Runbooks

- [ ] **Incident Response Runbook**
  - [ ] Steps for common issues
  - [ ] Escalation procedures
  - [ ] Contact information

- [ ] **Maintenance Runbook**
  - [ ] Update procedures
  - [ ] Backup procedures
  - [ ] Monitoring checklist

---

## 🎉 Go-Live

### Final Checks

- [ ] **All Checklist Items Complete**
- [ ] **Team Notified**
- [ ] **Monitoring Dashboard Open**
- [ ] **Backup Verified**

### Announce

- [ ] **Users Notified**
  - [ ] Announce in Slack/Discord/etc.
  - [ ] Share URL
  - [ ] Provide support channel

- [ ] **Documentation Published**
  - [ ] User guide available
  - [ ] API documentation accessible
  - [ ] FAQ updated

### Monitor First 24 Hours

- [ ] **Hour 1**: Check every 15 minutes
- [ ] **Hour 2-6**: Check hourly
- [ ] **Hour 6-24**: Check every 4 hours

---

## 📅 Post-Launch

### Day 1-7

- [ ] Monitor error rates
- [ ] Review performance metrics
- [ ] Verify backup completion
- [ ] Address any user issues

### Week 2-4

- [ ] Review security logs
- [ ] Optimize performance bottlenecks
- [ ] Update documentation based on learnings
- [ ] Plan for scaling if needed

### Month 2+

- [ ] Conduct security audit
- [ ] Test disaster recovery
- [ ] Review cost optimization
- [ ] Plan feature rollouts

---

## 🆘 Rollback Plan

If deployment fails, have a rollback plan:

- [ ] **Rollback Steps Documented**
  1. Stop new deployment
  2. Restore previous version
  3. Verify old version works
  4. Investigate issues
  5. Fix and redeploy

- [ ] **Backup of Previous Version**
  - [ ] Old deployment backed up
  - [ ] Database backup before deployment
  - [ ] Quick restore tested

---

## ✅ Checklist Complete!

🎉 **Congratulations! Your Liam deployment is complete and production-ready!**

### What's Next?

1. ✅ **Monitor** - Keep an eye on metrics and logs
2. 📊 **Optimize** - Tune performance based on real usage
3. 🔒 **Secure** - Regular security audits
4. 📈 **Scale** - Add resources as needed
5. 🔄 **Update** - Keep dependencies current

**Need help?** Check [DEPLOYMENT.md](DEPLOYMENT.md) or open an issue on GitHub.

---

**Deployment Date**: _____________  
**Deployed By**: _____________  
**Production URL**: _____________  
**Next Review Date**: _____________

