# 🔒 Liam Security Guide

**Production Security Best Practices & Hardening**

---

## 📋 Table of Contents

1. [Security Checklist](#security-checklist)
2. [Secrets Management](#secrets-management)
3. [Authentication & Authorization](#authentication--authorization)
4. [Network Security](#network-security)
5. [API Security](#api-security)
6. [Database Security](#database-security)
7. [Monitoring & Incident Response](#monitoring--incident-response)
8. [Security Updates](#security-updates)

---

## ✅ Security Checklist

### Pre-Production Checklist

Use this checklist before deploying to production:

- [ ] All environment variables configured in `.env.local`
- [ ] No secrets committed to git (`git log -S "sk-" --all`)
- [ ] OAuth keys rotated from defaults
- [ ] Sentry DSN configured for error tracking
- [ ] Database backups scheduled
- [ ] HTTPS enabled on all endpoints
- [ ] CORS configured properly
- [ ] Rate limiting enabled on APIs
- [ ] Security headers configured
- [ ] Dependency vulnerabilities scanned
- [ ] Penetration testing completed
- [ ] Incident response plan documented
- [ ] Team trained on security procedures

### Regular Security Tasks

- [ ] **Weekly**: Review access logs
- [ ] **Monthly**: Rotate API keys
- [ ] **Monthly**: Update dependencies (`pnpm update`)
- [ ] **Monthly**: Review Sentry errors
- [ ] **Quarterly**: Security audit
- [ ] **Quarterly**: Penetration testing
- [ ] **Yearly**: Comprehensive security review

---

## 🔐 Secrets Management

### Required Secrets

Liam requires the following secrets in `.env.local`:

```bash
# AI Model API Keys
OPENAI_API_KEY="sk-..."                    # OpenAI API key
ANTHROPIC_API_KEY="sk-ant-..."             # Anthropic API key

# Database
POSTGRES_URL="postgresql://..."            # Database connection string
SUPABASE_SERVICE_ROLE_KEY="eyJhbGc..."   # Supabase admin key

# OAuth
GITHUB_CLIENT_SECRET="..."                 # GitHub OAuth secret
LIAM_GITHUB_OAUTH_KEYRING="k2025-01:..."  # OAuth encryption key

# Monitoring
SENTRY_AUTH_TOKEN="..."                    # Sentry deployment token
LANGSMITH_API_KEY="..."                    # LangSmith tracing key

# Email (Optional)
RESEND_API_KEY="..."                       # Resend email API key
```

### Secrets Rotation Schedule

**High Priority (Rotate Every 30 Days):**
- `GITHUB_CLIENT_SECRET`
- `SUPABASE_SERVICE_ROLE_KEY`
- `LIAM_GITHUB_OAUTH_KEYRING`

**Medium Priority (Rotate Every 90 Days):**
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `SENTRY_AUTH_TOKEN`

**Low Priority (Rotate Every 180 Days):**
- `RESEND_API_KEY`
- `LANGSMITH_API_KEY`

### Secrets Rotation Procedure

#### 1. Generate New OAuth Keyring

```bash
# Generate new key
NEW_KEY=$(node -e "console.log('k2025-01:' + require('crypto').randomBytes(32).toString('base64'))")

# Add to keyring (keep old key for graceful rollover)
echo "LIAM_GITHUB_OAUTH_KEYRING=\"$NEW_KEY,<old-key>\"" >> .env.local

# After 24 hours, remove old key
# Edit .env.local and remove old key from keyring
```

#### 2. Rotate Database Credentials

```bash
# 1. Create new Supabase service role key in dashboard
# 2. Update .env.local
SUPABASE_SERVICE_ROLE_KEY="<new-key>"

# 3. Test connection
psql "$POSTGRES_URL" -c "SELECT 1;"

# 4. Restart services
./ACTIONS/stop.sh
./ACTIONS/start.sh

# 5. Revoke old key in Supabase dashboard
```

#### 3. Rotate API Keys

```bash
# OpenAI
# 1. Create new key at https://platform.openai.com/api-keys
# 2. Update .env.local
OPENAI_API_KEY="sk-..."

# 3. Test
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"

# 4. Restart services
./ACTIONS/stop.sh && ./ACTIONS/start.sh

# 5. Revoke old key in OpenAI dashboard
```

### Secrets Storage Best Practices

**❌ NEVER:**
- Commit secrets to git
- Share secrets via email or Slack
- Store secrets in application code
- Use same secrets across environments
- Leave default/example secrets in production

**✅ ALWAYS:**
- Use environment variables
- Use encrypted secrets managers (AWS Secrets Manager, Vault)
- Rotate secrets regularly
- Use different secrets per environment
- Audit secrets access
- Enable MFA on accounts with secrets

### Secrets Scanning

Run TruffleHog to detect accidentally committed secrets:

```bash
# Install TruffleHog
pip install truffleHog3

# Scan repository
trufflehog3 --no-history .

# Scan specific file
trufflehog3 --file .env.local

# Scan git history
trufflehog3 --repo https://github.com/Zeeeepa/liam
```

If secrets are found in git history:

```bash
# Use BFG Repo-Cleaner to remove secrets
# https://rtyley.github.io/bfg-repo-cleaner/

# 1. Clone a fresh copy
git clone --mirror https://github.com/Zeeeepa/liam.git

# 2. Remove secrets
bfg --replace-text secrets.txt liam.git

# 3. Clean up
cd liam.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 4. Force push (coordinate with team!)
git push --force
```

---

## 🔑 Authentication & Authorization

### GitHub OAuth Security

**OAuth Configuration:**

```bash
# In .env.local
GITHUB_CLIENT_ID="Iv1...."                # Public client ID
GITHUB_CLIENT_SECRET="..."                 # SECRET - rotate regularly
GITHUB_APP_ID="12345"                      # GitHub App ID
LIAM_GITHUB_OAUTH_KEYRING="..."           # Encryption keyring
```

**Security Measures:**

1. **Callback URL Validation**
   - Only whitelist production domains
   - Use HTTPS for all callbacks
   - Verify state parameter

2. **Token Storage**
   - Tokens encrypted with `LIAM_GITHUB_OAUTH_KEYRING`
   - Stored in HttpOnly cookies
   - Short expiration (7 days)

3. **Scope Minimization**
   - Only request necessary scopes
   - Review permissions regularly

### Session Security

**Cookie Configuration:**

```typescript
// Secure cookie settings
const cookieOptions = {
  httpOnly: true,           // Prevents XSS
  secure: true,              // HTTPS only
  sameSite: 'lax',          // CSRF protection
  maxAge: 7 * 24 * 60 * 60, // 7 days
  path: '/',
}
```

**Session Management:**

```bash
# Clear all sessions (emergency)
# Delete all cookies or run:
curl -X POST http://localhost:3001/api/logout
```

---

## 🌐 Network Security

### Firewall Rules

**Recommended iptables rules:**

```bash
# Allow only necessary ports
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT   # SSH
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT   # HTTP
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT  # HTTPS
sudo iptables -A INPUT -j DROP                       # Drop all other

# Rate limiting
sudo iptables -A INPUT -p tcp --dport 80 -m limit --limit 100/minute -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -m limit --limit 100/minute -j ACCEPT
```

### CORS Configuration

**Restrict origins in production:**

```typescript
// In next.config.ts
const corsHeaders = {
  'Access-Control-Allow-Origin': process.env.NEXT_PUBLIC_BASE_URL || '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
}
```

### Content Security Policy

**Add CSP headers:**

```nginx
# In nginx.conf
add_header Content-Security-Policy "
  default-src 'self';
  script-src 'self' 'unsafe-inline' 'unsafe-eval';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  font-src 'self' data:;
  connect-src 'self' https://api.openai.com https://*.supabase.co;
  frame-ancestors 'none';
" always;
```

---

## 🛡️ API Security

### Rate Limiting

**Implement rate limiting on critical endpoints:**

```typescript
// Example rate limiter middleware
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, '10 s'), // 10 requests per 10 seconds
})

export async function rateLimit(request: Request) {
  const ip = request.headers.get('x-forwarded-for') ?? 'anonymous'
  const { success, limit, remaining } = await ratelimit.limit(ip)
  
  if (!success) {
    return new Response('Rate limit exceeded', { status: 429 })
  }
  
  return null // Allow request
}
```

**Apply to endpoints:**

```typescript
// In app/api/chat/stream/route.ts
export async function POST(request: Request) {
  // Rate limit check
  const rateLimitResponse = await rateLimit(request)
  if (rateLimitResponse) return rateLimitResponse
  
  // Process request...
}
```

### Input Validation

**Always validate and sanitize inputs:**

```typescript
import * as v from 'valibot'

// Define schema
const ChatRequestSchema = v.object({
  message: v.pipe(
    v.string(),
    v.minLength(1, 'Message cannot be empty'),
    v.maxLength(5000, 'Message too long'),
  ),
  sessionId: v.pipe(
    v.string(),
    v.regex(/^[a-zA-Z0-9-]+$/, 'Invalid session ID'),
  ),
})

// Validate request
try {
  const data = v.parse(ChatRequestSchema, await request.json())
  // Proceed with validated data
} catch (error) {
  return new Response('Invalid request', { status: 400 })
}
```

### API Authentication

**Protect sensitive endpoints:**

```typescript
// API key authentication middleware
export async function authenticateAPIKey(request: Request) {
  const apiKey = request.headers.get('X-API-Key')
  
  if (!apiKey || !isValidAPIKey(apiKey)) {
    return new Response('Unauthorized', { status: 401 })
  }
  
  return null // Authenticated
}
```

---

## 💾 Database Security

### Connection Security

**Use SSL for database connections:**

```bash
# In .env.local
POSTGRES_URL="postgresql://user:pass@host:5432/db?sslmode=require"
```

### Row Level Security (RLS)

Supabase RLS is enabled by default. Verify policies:

```sql
-- Check RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public';
```

### Database Backups

**Automated backup schedule:**

```bash
# Daily backups with 30-day retention
0 2 * * * /path/to/liam/ACTIONS/backup.sh --compress --retention 30 --s3-bucket liam-backups

# Weekly encrypted backups
0 3 * * 0 /path/to/liam/ACTIONS/backup.sh --compress --encrypt --s3-bucket liam-backups-encrypted
```

### SQL Injection Prevention

**Always use parameterized queries:**

```typescript
// ❌ BAD - SQL injection vulnerable
const result = await supabase.rpc('get_user', {
  query: `SELECT * FROM users WHERE email = '${email}'`
})

// ✅ GOOD - Parameterized query
const result = await supabase
  .from('users')
  .select('*')
  .eq('email', email)
  .single()
```

---

## 📊 Monitoring & Incident Response

### Security Monitoring

**Monitor these metrics:**

1. **Failed Authentication Attempts**
   - Alert on >10 failures from same IP in 5 minutes
   
2. **Unusual API Usage**
   - Alert on >1000 requests per minute
   - Alert on unusual endpoints being called
   
3. **Database Queries**
   - Alert on slow queries (>1s)
   - Alert on failed queries
   
4. **Error Rates**
   - Alert on error rate >1%
   - Alert on 500 errors

### Sentry Configuration

```typescript
// In sentry.client.config.ts
import * as Sentry from '@sentry/nextjs'

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NEXT_PUBLIC_ENV_NAME,
  
  // Sample rate for performance monitoring
  tracesSampleRate: 0.1,
  
  // Filter sensitive data
  beforeSend(event) {
    // Remove sensitive headers
    if (event.request?.headers) {
      delete event.request.headers['Authorization']
      delete event.request.headers['Cookie']
    }
    return event
  },
  
  // Ignore known errors
  ignoreErrors: [
    'ResizeObserver loop limit exceeded',
    'Non-Error promise rejection',
  ],
})
```

### Incident Response Plan

**When a security incident is detected:**

1. **Immediate Response (0-15 minutes)**
   - Identify the scope
   - Stop the attack if ongoing
   - Preserve logs and evidence

2. **Assessment (15-60 minutes)**
   - Determine impact
   - Identify affected systems/data
   - Notify stakeholders

3. **Containment (1-4 hours)**
   - Isolate affected systems
   - Rotate compromised credentials
   - Block attack vectors

4. **Recovery (4-24 hours)**
   - Restore from backups if needed
   - Verify system integrity
   - Gradually restore service

5. **Post-Incident (24-72 hours)**
   - Root cause analysis
   - Document lessons learned
   - Implement preventive measures
   - Notify users if required

### Emergency Contacts

```
Security Team: security@your-domain.com
On-Call: +1-XXX-XXX-XXXX
Sentry: https://sentry.io/organizations/your-org/
AWS Console: https://console.aws.amazon.com/
```

---

## 🔄 Security Updates

### Dependency Updates

**Regular update schedule:**

```bash
# Check for vulnerabilities
pnpm audit

# Update dependencies
pnpm update

# Check for outdated packages
pnpm outdated

# Interactive update
pnpm up -i
```

### CVE Monitoring

**Monitor security advisories:**

- GitHub Dependabot (enabled)
- NPM security advisories
- Snyk vulnerability database
- CVE database

### Update Procedure

1. **Review changelog** for breaking changes
2. **Update in development** first
3. **Run full test suite**
4. **Deploy to staging**
5. **Verify functionality**
6. **Deploy to production**
7. **Monitor for issues**

---

## 📝 Security Audit Checklist

Run this audit quarterly:

### Code Review

- [ ] No hard-coded secrets
- [ ] All inputs validated
- [ ] SQL injection prevented
- [ ] XSS prevention in place
- [ ] CSRF tokens used
- [ ] Error messages don't leak sensitive info

### Infrastructure

- [ ] HTTPS everywhere
- [ ] Security headers configured
- [ ] Firewall rules in place
- [ ] SSH key-only authentication
- [ ] Automatic security updates enabled
- [ ] Backups tested and working

### Access Control

- [ ] Principle of least privilege applied
- [ ] MFA enabled for all accounts
- [ ] Regular access reviews
- [ ] Inactive accounts disabled
- [ ] Strong password policy enforced

### Monitoring

- [ ] Logging enabled
- [ ] Log retention policy in place
- [ ] Alerts configured
- [ ] Incident response plan tested
- [ ] Security metrics tracked

---

## 🚨 Security Incidents

### Reporting

If you discover a security vulnerability:

1. **DO NOT** open a public GitHub issue
2. Email: security@your-domain.com
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response SLA

- **Critical**: Response within 4 hours
- **High**: Response within 24 hours
- **Medium**: Response within 72 hours
- **Low**: Response within 1 week

---

## ✅ Security Compliance

### Data Protection

- **GDPR**: User data rights documented
- **CCPA**: California privacy rights honored
- **SOC 2**: Controls documented and tested

### Regular Reviews

- **Monthly**: Security metrics review
- **Quarterly**: Full security audit
- **Annually**: Penetration testing
- **Annually**: Compliance audit

---

**🔒 Remember: Security is everyone's responsibility!**

For questions or concerns, contact: security@your-domain.com

