# 🔑 Liam Project Requirements

This file contains the **ONLY** environment variable you need to manually configure. All other variables are automatically retrieved from deployed services or pre-defined.

## 📋 How to Use

1. Copy this file: `cp requirements.md .env`
2. Edit `.env` and add your Google Gemini API key (the only required manual input)
3. Run the setup script: `./start.sh` (automatically handles everything else)

---

## 🚨 MANUAL INPUT REQUIRED (Only 1 Variable!)

### 🤖 AI Service Configuration
```bash
# Google Gemini API Key (ONLY REQUIRED MANUAL INPUT)
# Get your key from: https://makersuite.google.com/app/apikey
GOOGLE_API_KEY="AIzaSyC_your_actual_gemini_api_key_here"
```

---

## 🤖 AUTOMATICALLY CONFIGURED (No Manual Input Required)

### 🗄️ Database Configuration (Auto-Retrieved from Supabase)
```bash
# Supabase Configuration (AUTO-CONFIGURED)
# These are automatically retrieved when start.sh runs 'supabase start'
NEXT_PUBLIC_SUPABASE_URL="http://localhost:54321"
NEXT_PUBLIC_SUPABASE_ANON_KEY="AUTO_RETRIEVED_FROM_SUPABASE_START"
SUPABASE_SERVICE_ROLE_KEY="AUTO_RETRIEVED_FROM_SUPABASE_START"

# Database URLs (AUTO-CONFIGURED)
# Pre-defined for local Supabase development
POSTGRES_URL="postgresql://postgres:postgres@localhost:54322/postgres"
POSTGRES_URL_NON_POOLING="postgresql://postgres:postgres@localhost:54322/postgres"
```

### ⚡ Background Job Processing (Auto-Configured for Development)
```bash
# Trigger.dev Configuration (AUTO-CONFIGURED)
# Uses development mode - no external signup required for local development
TRIGGER_PROJECT_ID="dev-local-project"
TRIGGER_SECRET_KEY="dev-local-secret"
```

### 🌐 Application Settings (Pre-Defined)
```bash
# Application Configuration (PRE-DEFINED)
NEXT_PUBLIC_BASE_URL="http://localhost:3000"
NEXT_PUBLIC_ENV_NAME="development"
MIGRATION_ENABLED="true"
```

---

## 🔧 OPTIONAL ENHANCEMENTS (Manual Configuration for Advanced Features)

> **Note**: These are completely optional. The system works fully without them.

### 📊 AI Observability & Monitoring
```bash
# Langfuse (AI Observability) - OPTIONAL
# Sign up at: https://cloud.langfuse.com for AI interaction tracking
LANGFUSE_BASE_URL="https://cloud.langfuse.com"
LANGFUSE_PUBLIC_KEY=""
LANGFUSE_SECRET_KEY=""
```

### 🐛 Error Tracking
```bash
# Sentry (Error Tracking) - OPTIONAL
# Sign up at: https://sentry.io for error monitoring
SENTRY_DSN=""
SENTRY_ORG=""
SENTRY_PROJECT=""
SENTRY_AUTH_TOKEN=""
```

### 📧 Email Service
```bash
# Resend (Email Service) - OPTIONAL
# Sign up at: https://resend.com for notifications
RESEND_API_KEY=""
RESEND_EMAIL_FROM_ADDRESS=""
```

### 🔗 GitHub Integration
```bash
# GitHub App Integration - OPTIONAL
# For repository analysis features
GITHUB_APP_ID=""
GITHUB_CLIENT_ID=""
GITHUB_CLIENT_SECRET=""
GITHUB_PRIVATE_KEY=""
NEXT_PUBLIC_GITHUB_APP_URL=""
```

### 🚩 Feature Flags
```bash
# Feature Flags - OPTIONAL
FLAGS_SECRET=""
```

---

## 🎯 Ultra-Simple Quick Start

### **Only 3 Steps to Full System!**
1. **🔑 Get Google Gemini API Key**: [Google AI Studio](https://makersuite.google.com/app/apikey) (30 seconds)
2. **📝 Add to .env**: `cp requirements.md .env` and paste your API key (30 seconds)
3. **🚀 Launch Everything**: `./start.sh` (auto-handles everything else - 3-5 minutes)

**That's it! No external signups, no complex configuration, no manual database setup.**

---

## 🔍 API Key Validation

### Google Gemini API Key Format (Only Manual Input Required)
- Should start with `AIzaSy`
- Length: typically 39 characters
- Example: `AIzaSyC1234567890abcdefghijklmnopqrstuvwxyz`
- **Get yours**: [Google AI Studio](https://makersuite.google.com/app/apikey)

### Auto-Configured Services (No Manual Input)
- **Supabase**: Automatically started and configured locally
- **Trigger.dev**: Uses local development mode
- **Database**: Pre-configured PostgreSQL connection
- **Application**: Pre-defined settings for localhost

---

## 🚨 Security Notes

1. **Never commit your `.env` file to version control**
2. **Only your Google API key needs to be kept secure**
3. **All other services run locally in development mode**
4. **For production, you'll need to configure external services**

---

## 🆘 Troubleshooting

### Common Issues

**Google API Key Issues:**
- Ensure the API key has Generative AI API enabled in Google Cloud Console
- Check billing is set up (free tier available)
- Verify the key format starts with `AIzaSy`

**Docker/Supabase Issues:**
- Make sure Docker is running
- Check if ports 54321-54324 are available
- Try `docker ps` to see if containers are running

**System Requirements:**
- Node.js 18+ required
- pnpm 8+ required
- Docker required for Supabase
- Git required

**Port Conflicts:**
- Frontend: 3000
- Supabase API: 54321
- Database: 54322
- Supabase Studio: 54323

---

## 📞 Support

If you encounter issues:
1. **Check Docker is running**: `docker ps`
2. **Verify your Google API key**: Should start with `AIzaSy`
3. **Check the console output** from `./start.sh` for specific error messages
4. **Try restarting**: `./start.sh --stop` then `./start.sh`

---

## 🔄 Simplified Environment Reference

| Variable | Input Required | Auto-Configured | Purpose |
|----------|----------------|-----------------|---------|
| `GOOGLE_API_KEY` | ✅ **MANUAL** | ❌ | Powers all AI agents |
| `NEXT_PUBLIC_SUPABASE_URL` | ❌ | ✅ **AUTO** | Database connection |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | ❌ | ✅ **AUTO** | Retrieved from Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | ❌ | ✅ **AUTO** | Retrieved from Supabase |
| `TRIGGER_PROJECT_ID` | ❌ | ✅ **AUTO** | Local development mode |
| `TRIGGER_SECRET_KEY` | ❌ | ✅ **AUTO** | Local development mode |
| `POSTGRES_URL` | ❌ | ✅ **AUTO** | Pre-defined connection |
| All Optional Services | ❌ | ✅ **AUTO** | Empty (disabled) by default |

**Result**: Only 1 manual input required, everything else is automatic! 🎉

---

*Last updated: $(date)*
*For the latest documentation, visit: [Liam Documentation](https://liambx.com/docs)*
