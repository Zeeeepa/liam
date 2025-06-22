# 🔑 Liam Project Requirements

This file contains all the environment variables needed to run the Liam PMAgent system. Copy this file to `.env` and fill in your actual values.

## 📋 How to Use

1. Copy this file: `cp requirements.md .env`
2. Edit `.env` and replace all placeholder values with your actual API keys and configuration
3. Run the setup script: `./start.sh`

---

## 🚨 MANDATORY VARIABLES (Required for Basic Functionality)

### 🤖 AI Service Configuration
```bash
# Google Gemini API Key (REQUIRED)
# Get your key from: https://makersuite.google.com/app/apikey
GOOGLE_API_KEY="AIzaSyC_your_actual_gemini_api_key_here"
```

### 🗄️ Database Configuration (Supabase)
```bash
# Supabase Configuration (REQUIRED)
# These will be automatically set when you run 'supabase start'
# Leave as localhost for development, update for production
NEXT_PUBLIC_SUPABASE_URL="http://localhost:54321"
NEXT_PUBLIC_SUPABASE_ANON_KEY="your_supabase_anon_key_from_supabase_start"
SUPABASE_SERVICE_ROLE_KEY="your_supabase_service_role_key_from_supabase_start"

# Database URLs (REQUIRED)
# These will be set automatically for local development
POSTGRES_URL="postgresql://postgres:postgres@localhost:54322/postgres"
POSTGRES_URL_NON_POOLING="postgresql://postgres:postgres@localhost:54322/postgres"
```

### ⚡ Background Job Processing (Trigger.dev)
```bash
# Trigger.dev Configuration (REQUIRED)
# Sign up at: https://trigger.dev
# Create a project and get your credentials
TRIGGER_PROJECT_ID="proj_your_trigger_project_id"
TRIGGER_SECRET_KEY="tr_dev_your_trigger_secret_key"
```

### 🌐 Application Settings
```bash
# Application Configuration (REQUIRED)
NEXT_PUBLIC_BASE_URL="http://localhost:3000"
NEXT_PUBLIC_ENV_NAME="development"
MIGRATION_ENABLED="true"
```

---

## 🔧 OPTIONAL VARIABLES (Enhanced Features)

### 📊 AI Observability & Monitoring
```bash
# Langfuse (AI Observability) - OPTIONAL but RECOMMENDED
# Sign up at: https://cloud.langfuse.com
# Provides detailed AI interaction tracking and analytics
LANGFUSE_BASE_URL="https://cloud.langfuse.com"
LANGFUSE_PUBLIC_KEY="pk_lf_your_langfuse_public_key"
LANGFUSE_SECRET_KEY="sk_lf_your_langfuse_secret_key"
```

### 🐛 Error Tracking
```bash
# Sentry (Error Tracking) - OPTIONAL but RECOMMENDED
# Sign up at: https://sentry.io
# Provides error monitoring and performance tracking
SENTRY_DSN="https://your_sentry_dsn@sentry.io/project_id"
SENTRY_ORG="your_sentry_org"
SENTRY_PROJECT="your_sentry_project"
SENTRY_AUTH_TOKEN="your_sentry_auth_token"
```

### 📧 Email Service
```bash
# Resend (Email Service) - OPTIONAL
# Sign up at: https://resend.com
# Used for sending notifications and alerts
RESEND_API_KEY="re_your_resend_api_key"
RESEND_EMAIL_FROM_ADDRESS="noreply@yourdomain.com"
```

### 🔗 GitHub Integration
```bash
# GitHub App Integration - OPTIONAL
# Create a GitHub App for repository analysis features
# Follow: https://docs.github.com/en/developers/apps/building-github-apps
GITHUB_APP_ID="your_github_app_id"
GITHUB_CLIENT_ID="your_github_client_id"
GITHUB_CLIENT_SECRET="your_github_client_secret"
GITHUB_PRIVATE_KEY="your_github_private_key_base64_encoded"
NEXT_PUBLIC_GITHUB_APP_URL="https://github.com/apps/your-app-name"
```

### 🚩 Feature Flags
```bash
# Feature Flags - OPTIONAL
# Used for A/B testing and feature rollouts
FLAGS_SECRET="your_feature_flags_secret"
```

---

## 🎯 Quick Start Checklist

### Minimum Setup (Basic Functionality)
- [ ] ✅ Get Google Gemini API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
- [ ] ✅ Sign up for [Trigger.dev](https://trigger.dev) and create a project
- [ ] ✅ Copy this file to `.env` and fill in the MANDATORY variables
- [ ] ✅ Run `./start.sh` to set up and launch the system

### Recommended Setup (Full Features)
- [ ] 📊 Sign up for [Langfuse](https://cloud.langfuse.com) for AI observability
- [ ] 🐛 Sign up for [Sentry](https://sentry.io) for error tracking
- [ ] 📧 Sign up for [Resend](https://resend.com) for email notifications
- [ ] 🔗 Create GitHub App for repository integration (optional)

---

## 🔍 API Key Validation

### Google Gemini API Key Format
- Should start with `AIzaSy`
- Length: typically 39 characters
- Example: `AIzaSyC1234567890abcdefghijklmnopqrstuvwxyz`

### Trigger.dev Keys Format
- Project ID: starts with `proj_`
- Secret Key: starts with `tr_dev_` (development) or `tr_prod_` (production)

### Supabase Keys Format
- Anon Key: JWT token starting with `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9`
- Service Role Key: JWT token starting with `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9`

---

## 🚨 Security Notes

1. **Never commit your `.env` file to version control**
2. **Use different API keys for development and production**
3. **Regularly rotate your API keys**
4. **Keep your Supabase service role key secure - it has admin privileges**
5. **Use environment-specific Trigger.dev projects**

---

## 🆘 Troubleshooting

### Common Issues

**Google API Key Issues:**
- Ensure the API key has Generative AI API enabled
- Check billing is set up in Google Cloud Console
- Verify the key hasn't exceeded rate limits

**Supabase Connection Issues:**
- Make sure Docker is running
- Check if ports 54321-54324 are available
- Try `supabase stop && supabase start` to reset

**Trigger.dev Issues:**
- Verify project ID and secret key are correct
- Check if you're using the right environment (dev/prod)
- Ensure your Trigger.dev project is active

**Database Issues:**
- Ensure PostgreSQL port 54322 is not in use
- Check Docker has enough resources allocated
- Verify database migrations completed successfully

---

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Verify all mandatory environment variables are set
3. Check the console output from `./start.sh` for specific error messages
4. Ensure all external services (Google AI, Trigger.dev, etc.) are properly configured

---

## 🔄 Environment Variable Reference

| Variable | Required | Service | Purpose |
|----------|----------|---------|---------|
| `GOOGLE_API_KEY` | ✅ Yes | Google AI | Powers all AI agents |
| `TRIGGER_PROJECT_ID` | ✅ Yes | Trigger.dev | Background job processing |
| `TRIGGER_SECRET_KEY` | ✅ Yes | Trigger.dev | Authentication |
| `NEXT_PUBLIC_SUPABASE_URL` | ✅ Yes | Supabase | Database connection |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | ✅ Yes | Supabase | Public API access |
| `SUPABASE_SERVICE_ROLE_KEY` | ✅ Yes | Supabase | Admin API access |
| `POSTGRES_URL` | ✅ Yes | PostgreSQL | Direct database access |
| `LANGFUSE_PUBLIC_KEY` | 🔧 Optional | Langfuse | AI observability |
| `SENTRY_DSN` | 🔧 Optional | Sentry | Error tracking |
| `RESEND_API_KEY` | 🔧 Optional | Resend | Email notifications |

---

*Last updated: $(date)*
*For the latest documentation, visit: [Liam Documentation](https://liambx.com/docs)*

