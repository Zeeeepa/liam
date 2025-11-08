# 🚀 Liam - Complete Setup & Usage Instructions

**AI-Powered Database Schema Designer with PRD-to-SQL Automation**

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [System Requirements](#system-requirements)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Starting & Stopping](#starting--stopping)
6. [Usage Guide](#usage-guide)
7. [Agent System](#agent-system)
8. [GitHub Integration](#github-integration)
9. [Troubleshooting](#troubleshooting)
10. [Advanced Configuration](#advanced-configuration)
11. [Development](#development)
12. [Production Deployment](#production-deployment)

---

## ⚡ Quick Start

### 60-Second Setup

```bash
# 1. Clone the repository (if not already done)
git clone https://github.com/Zeeeepa/liam.git
cd liam

# 2. Run setup script
./ACTIONS/setup.sh

# 3. Configure environment
# Edit .env.local with your API keys

# 4. Start the application
./ACTIONS/start.sh

# 5. Open browser
# Navigate to: http://localhost:3001
```

### First Test

Once the application is running:

1. Open http://localhost:3001
2. Type in the chat: `Create a blog system with users and posts`
3. Watch the AI agents work in real-time! 🤖

---

## 💻 System Requirements

### Minimum Requirements

- **OS**: Ubuntu 20.04+, macOS 12+, or Windows (WSL2)
- **RAM**: 4 GB
- **Disk**: 5 GB free space
- **Network**: Internet connection for API calls

### Recommended Requirements

- **OS**: Ubuntu 22.04+ or macOS 13+
- **RAM**: 8 GB+
- **Disk**: 10 GB+ free space
- **CPU**: 4+ cores

### Software Dependencies

**Automatically installed by `setup.sh`:**
- Node.js 20+
- pnpm 10+
- Build tools (gcc, make)

**Optional:**
- PostgreSQL client (for database testing)
- Docker (for containerized deployment)

---

## 📦 Installation

### Method 1: Automated Setup (Recommended)

```bash
cd liam
./ACTIONS/setup.sh
```

**What this does:**
- ✅ Detects your environment (OS, WSL, etc.)
- ✅ Installs Node.js 20+ and pnpm 10+
- ✅ Installs all project dependencies (~2000 packages)
- ✅ Creates environment configuration files
- ✅ Generates OAuth encryption keys
- ✅ Validates database connections

**Options:**
```bash
./ACTIONS/setup.sh --skip-deps    # Skip system dependencies
./ACTIONS/setup.sh --skip-build   # Skip build (use dev mode)
./ACTIONS/setup.sh --help         # Show all options
```

### Method 2: Manual Setup

```bash
# 1. Install Node.js 20+
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Install pnpm
npm install -g pnpm

# 3. Install dependencies
cd liam
pnpm install

# 4. Configure environment
cp .env.template .env.local
# Edit .env.local with your settings

# 5. Generate OAuth key
node -e "console.log('LIAM_GITHUB_OAUTH_KEYRING=\"k2025-01:' + require('crypto').randomBytes(32).toString('base64') + '\"')" >> .env.local
```

---

## ⚙️ Configuration

### Environment Variables

Edit `.env.local` to configure Liam:

#### Required Variables

```bash
# AI Model API (Z.AI example)
OPENAI_API_KEY="your-api-key-here"
OPENAI_BASE_URL="https://api.z.ai/api/openai"

# OR for OpenAI directly
OPENAI_API_KEY="sk-your-openai-key"

# Database (Supabase example)
NEXT_PUBLIC_SUPABASE_URL="https://your-project.supabase.co"
NEXT_PUBLIC_SUPABASE_ANON_KEY="your-anon-key"
POSTGRES_URL="postgresql://user:pass@host:5432/database"
SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"

# Application
NEXT_PUBLIC_BASE_URL="http://localhost:3001"
NEXT_PUBLIC_ENV_NAME="development"
```

#### Optional Variables

```bash
# GitHub OAuth (for repository integration)
GITHUB_CLIENT_ID="your-github-client-id"
GITHUB_CLIENT_SECRET="your-github-client-secret"

# LangSmith (for agent debugging)
LANGSMITH_API_KEY="your-langsmith-key"
LANGSMITH_PROJECT="liam-development"

# Sentry (for error tracking)
SENTRY_DSN="your-sentry-dsn"
SENTRY_PROJECT="liam"

# Email (Resend)
RESEND_API_KEY="your-resend-key"
RESEND_EMAIL_FROM_ADDRESS="noreply@yourdomain.com"
```

### API Provider Configuration

#### Z.AI (Recommended for Cost)

```bash
OPENAI_BASE_URL="https://api.z.ai/api/openai"
OPENAI_API_KEY="your-zai-key"
ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
ANTHROPIC_MODEL="glm-4.6"
```

**Models available:**
- `gpt-5` - Strongest reasoning (PM Agent)
- `gpt-5-mini` - Balanced (DB Agent)
- `gpt-5-nano` - Fast (Lead & QA Agents)

#### OpenAI (Standard)

```bash
OPENAI_API_KEY="sk-your-openai-key"
# No BASE_URL needed
```

**Models available:**
- `gpt-4o` - Latest GPT-4 Omni
- `gpt-4-turbo` - Fast GPT-4
- `gpt-3.5-turbo` - Cost-effective

#### Anthropic (Claude)

```bash
ANTHROPIC_API_KEY="your-anthropic-key"
ANTHROPIC_MODEL="claude-3-5-sonnet-20241022"
```

### Database Configuration

#### Supabase (Recommended)

```bash
NEXT_PUBLIC_SUPABASE_URL="https://xxxxx.supabase.co"
NEXT_PUBLIC_SUPABASE_ANON_KEY="eyJhbGc..."
POSTGRES_URL="postgresql://postgres:pass@db.xxxxx.supabase.co:5432/postgres"
SUPABASE_SERVICE_ROLE_KEY="eyJhbGc..."
```

#### Local PostgreSQL

```bash
POSTGRES_URL="postgresql://postgres:password@localhost:5432/liam"
POSTGRES_URL_NON_POOLING="postgresql://postgres:password@localhost:5432/liam"
```

---

## 🎮 Starting & Stopping

### Starting Services

#### Start Main Application Only (Default)

```bash
./ACTIONS/start.sh
```

**Features:**
- Development mode with hot reload
- Port: 3001
- Real-time compilation

#### Start All Services

```bash
./ACTIONS/start.sh --all
```

**Starts:**
- Main app (port 3001)
- Documentation site (port 3002)
- MCP server

#### Start in Production Mode

```bash
# First build
pnpm build --filter @liam-hq/app

# Then start
./ACTIONS/start.sh --production
```

**Features:**
- Optimized bundles
- Faster performance
- No hot reload

#### Background Mode

```bash
./ACTIONS/start.sh --background
```

**Features:**
- Runs in background
- Logs to `.liam-*.log` files
- Use `./ACTIONS/stop.sh` to stop

#### Custom Port

```bash
./ACTIONS/start.sh --port 3000
```

### Stopping Services

#### Stop All Services

```bash
./ACTIONS/stop.sh
```

#### Stop Specific Service

```bash
./ACTIONS/stop.sh --app-only     # Stop main app only
./ACTIONS/stop.sh --docs-only    # Stop docs only
./ACTIONS/stop.sh --mcp-only     # Stop MCP server only
```

#### Force Stop

```bash
./ACTIONS/stop.sh --force
```

**Use when:**
- Services won't stop gracefully
- Processes are hanging
- Ports remain blocked

#### Stop and Clean

```bash
./ACTIONS/stop.sh --clean
```

**Removes:**
- PID files
- Log files
- Next.js cache

---

## 📖 Usage Guide

### Basic Workflow

1. **Start the Application**
   ```bash
   ./ACTIONS/start.sh
   ```

2. **Open Browser**
   - Navigate to: http://localhost:3001

3. **Create a Schema**
   - Type a natural language description
   - Example: "Create a task management system"

4. **Watch the Agents**
   - Lead Agent routes the request
   - PM Agent analyzes requirements
   - DB Agent designs schema
   - QA Agent validates with tests

5. **Review & Export**
   - View ERD diagram
   - Download SQL DDL
   - See schema versions

### Example Prompts

#### Simple Schema

```
Create a users table with email, password, and created_at
```

**Expected output:**
- 1 table
- 3-4 columns
- Primary key
- Timestamps
- ~15-30 seconds

#### Moderate Schema

```
Create a blog system with users and posts. 
Users can write many posts.
Posts should have title, content, and published date.
```

**Expected output:**
- 2 tables
- Foreign key relationships
- Proper constraints
- ~30-45 seconds

#### Complex Schema

```
Create an e-commerce system with:
- Users with authentication
- Products with categories
- Shopping cart functionality
- Orders with multiple items
- Payment tracking
- Reviews and ratings
```

**Expected output:**
- 6-8 tables
- Many-to-many relationships
- Junction tables
- Complex constraints
- ~60-90 seconds

#### Schema Modification

```
Add a description column to the products table
```

**Expected output:**
- Existing schema updated
- New version created
- Tests updated
- ~20-30 seconds

### Advanced Features

#### Schema Versioning

Every change creates a new version:
- View version history
- Compare versions
- Rollback if needed

#### Test Generation

QA Agent automatically generates:
- INSERT tests (data creation)
- UPDATE tests (data modification)
- DELETE tests (referential integrity)
- SELECT tests (query validation)

#### ERD Visualization

Interactive diagram shows:
- Tables with columns
- Primary/foreign keys
- Relationships
- Constraints

#### SQL Export

Download production-ready:
- PostgreSQL DDL
- Table definitions
- Indexes
- Constraints

---

## 🤖 Agent System

### The 4-Agent Architecture

Liam uses 4 specialized AI agents working together:

#### 1. Lead Agent (Router)

**Model**: GPT-5-nano  
**Speed**: ~0.5 seconds  
**Role**: Orchestration

**Responsibilities:**
- Classifies incoming requests
- Routes to appropriate specialist agents
- Manages workflow execution
- Summarizes results

**Decision Logic:**
```
User input → Analyze intent → Route to:
  - PM Agent (requirements analysis)
  - DB Agent (schema design/modification)
  - QA Agent (validation only)
  - END (if complete)
```

#### 2. PM Agent (Requirements Analyst)

**Model**: GPT-5 (strongest reasoning)  
**Speed**: ~3-5 seconds  
**Role**: Business analysis

**Responsibilities:**
- Converts vague → structured requirements
- Creates Business Requirements Document (BRD)
- Generates test case specifications
- Fills gaps with reasonable assumptions

**Output Format:**
```typescript
{
  goal: string;              // Clear, actionable goal
  testcases: {
    [category: string]: {    // e.g., "User Management"
      title: string;         // Test description
      type: "INSERT" | "UPDATE" | "DELETE" | "SELECT";
      sql?: string;          // Expected SQL
    }[]
  }
}
```

**Example:**
```
Input: "Create a blog"
Output: {
  goal: "Design a blog system with users, posts, and comments",
  testcases: {
    "User Management": [
      { title: "User can register", type: "INSERT" }
    ],
    "Content Management": [
      { title: "User can create post", type: "INSERT" },
      { title: "Post can be published", type: "UPDATE" }
    ]
  }
}
```

#### 3. DB Agent (Schema Designer)

**Model**: GPT-5-mini (balanced)  
**Speed**: ~5-10 seconds  
**Role**: Database architecture

**Responsibilities:**
- Designs PostgreSQL schemas
- Applies JSON Patch operations (RFC 6902)
- Validates in PGLite (WASM Postgres)
- Creates schema versions in Supabase
- Handles errors with detailed feedback

**Workflow:**
```
1. Get current schema from Supabase
2. Generate JSON Patch operations
3. Apply patches to schema
4. Convert to PostgreSQL DDL
5. Validate in PGLite
6. If valid:
     Save to Supabase
     Return success
   Else:
     Parse error
     Return for retry
```

**Key Features:**
- **In-browser validation**: PGLite ensures DDL is correct
- **Version control**: Every change tracked
- **Atomic operations**: All-or-nothing commits
- **Error recovery**: Detailed feedback for retries

#### 4. QA Agent (Test Engineer)

**Model**: GPT-5-nano (fast)  
**Speed**: ~10-15 seconds  
**Role**: Quality assurance

**Responsibilities:**
- Generates DML test cases from BRD
- Runs tests with pgTAP framework
- Executes tests in parallel (map-reduce)
- Auto-retries failures (max 3 attempts)
- Provides detailed failure analysis

**Test Framework (pgTAP):**
```sql
-- Example test case
BEGIN;
  SELECT plan(3);
  
  -- Test 1: Table exists
  SELECT has_table('users');
  
  -- Test 2: Insert works
  INSERT INTO users (email, password) 
  VALUES ('test@example.com', 'hashed');
  SELECT ok(
    EXISTS(SELECT 1 FROM users WHERE email = 'test@example.com'),
    'User can be created'
  );
  
  -- Test 3: Constraint works
  SELECT throws_ok(
    'INSERT INTO users (email, password) VALUES (''test@example.com'', ''x'')',
    '23505',
    'Duplicate email prevented'
  );
  
  SELECT * FROM finish();
ROLLBACK;
```

**Test Types:**
- `lives_ok` - Operation succeeds
- `throws_ok` - Operation fails as expected
- `has_table` - Table exists
- `has_column` - Column exists
- `ok` - General assertion
- `is` - Value equality

### Agent Communication

Agents communicate via **LangGraph state**:

```typescript
interface WorkflowState {
  userInput: string;                        // Original request
  messages: BaseMessage[];                   // Conversation history
  schemaData: Schema;                        // Current schema (JSON)
  analyzedRequirements?: AnalyzedRequirements; // PM output
  testcases: Testcase[];                     // Generated tests
  designSessionId: string;                   // Unique session ID
  buildingSchemaId: string;                  // Schema version ID
  next?: "pmAgent" | "dbAgent" | "qaAgent" | "END";
  failureAnalysis?: {
    failedSqlTestIds: string[];
    failedSchemaTestIds: string[];
  };
}
```

### Workflow Execution

```
User Input
    ↓
[Lead Agent] → Classify & Route
    ↓
[PM Agent] → Analyze Requirements → BRD
    ↓
[DB Agent] → Design Schema → DDL
    ↓          ↓ (validation)
    ↓     [PGLite WASM]
    ↓          ↓
    ↓      ✅ Valid → Save to Supabase
    ↓      ❌ Invalid → Retry (with error details)
    ↓
[QA Agent] → Generate Tests → Run in pgTAP
    ↓          ↓
    ↓      ✅ All pass → Success
    ↓      ❌ Some fail → DB Agent retry
    ↓
[Lead Agent] → Summarize → Return to User
```

**Retry Logic:**
- PM Agent: Max 3 retries (if BRD unclear)
- DB Agent: Max 3 retries (if schema invalid)
- QA Agent: Max 3 retries per test (if test fails)

### Observability

**Real-Time Streaming:**
- See each agent's reasoning
- Watch tool calls execute
- View intermediate results
- Monitor test execution

**LangSmith Integration** (optional):
```bash
LANGSMITH_API_KEY="your-key"
LANGSMITH_PROJECT="liam-production"
LANGSMITH_TRACING="true"
```

**Benefits:**
- Trace full execution
- Debug agent decisions
- Analyze performance
- Optimize prompts

---

## 🔗 GitHub Integration

### Setup GitHub OAuth

1. **Create GitHub App**
   - Go to: https://github.com/settings/apps
   - Click "New GitHub App"
   - Settings:
     - Name: "Liam Schema Designer"
     - Homepage: `http://localhost:3001`
     - Callback URL: `http://localhost:3001/api/auth/callback`
     - Permissions:
       - Repository: Contents (Read & Write)
       - Issues: Read & Write
       - Pull Requests: Read & Write

2. **Configure Environment**
   ```bash
   # In .env.local
   GITHUB_CLIENT_ID="your-client-id"
   GITHUB_CLIENT_SECRET="your-client-secret"
   GITHUB_APP_ID="your-app-id"
   NEXT_PUBLIC_GITHUB_APP_URL="https://github.com/apps/your-app"
   ```

3. **Test Connection**
   - Start Liam: `./ACTIONS/start.sh`
   - Click "Connect GitHub" in UI
   - Authorize the app
   - Select repositories

### PRD-to-SQL Workflow

#### From GitHub Issues

1. **Create Issue** with PRD:
   ```markdown
   Title: Design User Management System
   
   ## Requirements
   - User registration with email/password
   - User authentication
   - Profile management
   - Password reset functionality
   
   ## Constraints
   - Email must be unique
   - Passwords must be hashed
   - Include audit timestamps
   ```

2. **Link to Liam**:
   - Mention `/liam design` in comment
   - Or use GitHub Actions integration

3. **Automated Response**:
   - Liam analyzes PRD
   - Generates schema
   - Posts ERD diagram
   - Attaches SQL DDL file

#### From GitHub PRs

1. **PR Description** includes:
   ```markdown
   ## Database Changes
   
   <!-- @liam analyze -->
   Need to add order tracking to existing e-commerce schema
   <!-- /liam -->
   ```

2. **Auto-Review**:
   - Liam detects changes
   - Analyzes schema modifications
   - Validates migrations
   - Comments on PR

### MCP Server for IDE

**Enable in Cursor/Claude Code:**

```json
// In settings.json
{
  "mcpServers": {
    "liam": {
      "command": "node",
      "args": [
        "/path/to/liam/frontend/internal-packages/mcp-server/src/index.ts"
      ],
      "env": {
        "SUPABASE_URL": "your-url",
        "SUPABASE_ANON_KEY": "your-key"
      }
    }
  }
}
```

**Available Tools:**
- `design_schema` - Generate schema from description
- `modify_schema` - Update existing schema
- `validate_schema` - Check schema validity
- `export_ddl` - Get PostgreSQL DDL

---

## 🔧 Troubleshooting

### Common Issues

#### Port Already in Use

**Problem:**
```
Error: Port 3001 is already in use
```

**Solutions:**
```bash
# Option 1: Stop existing process
./ACTIONS/stop.sh

# Option 2: Use different port
./ACTIONS/start.sh --port 3000

# Option 3: Kill process manually
lsof -ti:3001 | xargs kill -9
```

#### Dependencies Not Installed

**Problem:**
```
Error: Cannot find module '@liam-hq/agent'
```

**Solution:**
```bash
# Reinstall dependencies
rm -rf node_modules pnpm-lock.yaml
pnpm install
```

#### Environment Not Configured

**Problem:**
```
Error: OPENAI_API_KEY is not defined
```

**Solution:**
```bash
# Check .env.local exists
ls -la .env.local

# If not, create from template
cp .env.template .env.local

# Edit with your values
nano .env.local
```

#### API Connection Failed

**Problem:**
```
Error: Failed to connect to API
```

**Solutions:**
```bash
# Test API manually
curl https://api.z.ai/api/openai/models \
  -H "Authorization: Bearer YOUR_KEY"

# Check environment
cat .env.local | grep OPENAI_API_KEY

# Verify URL
cat .env.local | grep OPENAI_BASE_URL
```

#### Database Connection Failed

**Problem:**
```
Error: Connection to database failed
```

**Solutions:**
```bash
# Test connection
psql "$POSTGRES_URL"

# Check credentials
cat .env.local | grep POSTGRES_URL

# Verify Supabase is running
curl https://your-project.supabase.co/rest/v1/
```

#### Build Timeout

**Problem:**
```
Build taking too long (>10 minutes)
```

**Solutions:**
```bash
# Skip build, use dev mode
./ACTIONS/start.sh

# Or build specific app only
pnpm build --filter @liam-hq/app

# Clear cache and retry
rm -rf frontend/apps/app/.next
pnpm build --filter @liam-hq/app
```

#### Agent Not Responding

**Problem:**
- No response from agents
- Requests timeout

**Solutions:**
```bash
# Check API key is valid
curl $OPENAI_BASE_URL/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"

# Check logs for errors
tail -f .liam-app.log

# Restart services
./ACTIONS/stop.sh
./ACTIONS/start.sh
```

### Debug Mode

Enable verbose logging:

```bash
# In .env.local
DEBUG="*"
NODE_ENV="development"
LANGSMITH_TRACING="true"
```

View logs:
```bash
# Real-time logs
tail -f .liam-app.log

# Agent-specific logs
grep "Lead Agent" .liam-app.log
grep "PM Agent" .liam-app.log
grep "DB Agent" .liam-app.log
grep "QA Agent" .liam-app.log
```

---

## 🔬 Advanced Configuration

### Custom Agent Configuration

Edit `frontend/internal-packages/agent/src/config.ts`:

```typescript
export const agentConfig = {
  leadAgent: {
    model: "gpt-5-nano",
    temperature: 0.3,
    maxRetries: 3,
  },
  pmAgent: {
    model: "gpt-5",
    temperature: 0.5,
    maxRetries: 3,
    reasoningEffort: "medium",
  },
  dbAgent: {
    model: "gpt-5-mini",
    temperature: 0.2,
    maxRetries: 3,
  },
  qaAgent: {
    model: "gpt-5-nano",
    temperature: 0.1,
    maxRetries: 3,
    parallelTests: true,
  },
};
```

### Custom Validation Rules

Add custom pgTAP tests:

```sql
-- In frontend/internal-packages/agent/src/qa-agent/custom-tests.sql

-- Test naming conventions
CREATE OR REPLACE FUNCTION test_naming_conventions()
RETURNS SETOF TEXT AS $$
BEGIN
  RETURN NEXT has_table('users');
  RETURN NEXT col_is_pk('users', 'id');
  RETURN NEXT col_has_default('users', 'created_at');
END;
$$ LANGUAGE plpgsql;
```

### Performance Tuning

Optimize for your use case:

```bash
# In .env.local

# Increase timeout for complex schemas
AGENT_TIMEOUT="120000"  # 2 minutes

# Adjust parallel test execution
QA_PARALLEL_TESTS="10"

# Cache schema validation results
PGLITE_CACHE="true"
```

---

## 👨‍💻 Development

### Development Workflow

```bash
# Install dependencies
pnpm install

# Start dev server (hot reload)
pnpm dev

# Run tests
pnpm test

# Run E2E tests
pnpm test:e2e

# Format code
pnpm fmt

# Lint code
pnpm lint

# Type check
pnpm type-check
```

### Project Structure

```
liam/
├── ACTIONS/                    # Deployment scripts
│   ├── setup.sh               # Setup automation
│   ├── start.sh               # Start services
│   ├── stop.sh                # Stop services
│   └── INSTRUCTIONS.md        # This file
├── frontend/
│   ├── apps/
│   │   ├── app/               # Main Next.js app
│   │   └── docs/              # Documentation site
│   ├── packages/
│   │   ├── cli/               # CLI tool
│   │   ├── erd-core/          # ERD engine
│   │   ├── schema/            # Schema parser
│   │   └── ui/                # UI components
│   └── internal-packages/
│       ├── agent/             # 4-agent system
│       ├── db/                # Database utilities
│       ├── mcp-server/        # MCP integration
│       └── pglite-server/     # In-browser Postgres
├── docs/                      # Documentation
├── scripts/                   # Build scripts
└── .env.local                 # Configuration
```

### Testing

```bash
# Unit tests
pnpm test

# Watch mode
pnpm test --watch

# Coverage
pnpm test:coverage

# E2E tests
pnpm test:e2e

# Specific package
pnpm --filter @liam-hq/agent test
```

### Contributing

See guidelines in repository root:
- `CONTRIBUTING.md` - Contribution guide
- `AGENTS.md` - Agent development guide
- `CLAUDE.md` - Claude Code integration

---

## 🚀 Production Deployment

### Build for Production

```bash
# Build all packages
pnpm build

# Or build specific app
pnpm build --filter @liam-hq/app
```

### Deployment Options

#### Option 1: PM2 (Recommended)

```bash
# Install PM2
npm install -g pm2

# Start with PM2
cd frontend/apps/app
pm2 start "pnpm start" --name liam

# Save configuration
pm2 save

# Auto-start on boot
pm2 startup
```

#### Option 2: Docker

```dockerfile
# Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY . .
RUN npm install -g pnpm
RUN pnpm install --frozen-lockfile
RUN pnpm build --filter @liam-hq/app
CMD ["pnpm", "--filter", "@liam-hq/app", "start"]
```

```bash
# Build image
docker build -t liam .

# Run container
docker run -p 3001:3001 --env-file .env.local liam
```

#### Option 3: Vercel/Netlify

```bash
# Deploy to Vercel
pnpm vercel:link
pnpm vercel:env-pull
vercel deploy --prod
```

### Nginx Configuration

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        
        # SSE support
        proxy_set_header X-Accel-Buffering no;
        proxy_buffering off;
    }
}
```

### Environment Variables for Production

```bash
# .env.local (production)
NEXT_PUBLIC_ENV_NAME="production"
NEXT_PUBLIC_BASE_URL="https://your-domain.com"
NODE_ENV="production"

# Use strong secrets
LIAM_GITHUB_OAUTH_KEYRING="k2025-01:$(openssl rand -base64 32)"

# Enable monitoring
SENTRY_DSN="your-sentry-dsn"
LANGSMITH_PROJECT="liam-production"
```

### Security Checklist

- [ ] Change all default secrets
- [ ] Enable HTTPS
- [ ] Configure CORS properly
- [ ] Set up rate limiting
- [ ] Enable request logging
- [ ] Configure firewall rules
- [ ] Regular security updates
- [ ] Database backups enabled
- [ ] Error monitoring active
- [ ] Access logs reviewed

### Monitoring

```bash
# System monitoring
htop

# Application logs
tail -f .liam-app.log

# PM2 monitoring
pm2 monit

# Database monitoring
psql $POSTGRES_URL -c "SELECT * FROM pg_stat_activity;"
```

---

## 📚 Additional Resources

### Documentation

- **Quick Start**: This file (INSTRUCTIONS.md)
- **Setup Guide**: `../SETUP_COMPLETE.md`
- **Deployment Manual**: `../DEPLOYMENT_GUIDE.md`
- **API Documentation**: `frontend/apps/docs/`
- **Agent Guide**: `frontend/internal-packages/agent/README.md`

### Community

- **GitHub Issues**: Report bugs and feature requests
- **Discussions**: Ask questions and share ideas
- **Contributing**: See CONTRIBUTING.md

### Support

For help:
1. Check troubleshooting section above
2. Search existing GitHub issues
3. Create new issue with:
   - Environment details
   - Error messages
   - Steps to reproduce

---

## ✨ Summary

**Liam provides:**
- ✅ 4 specialized AI agents for schema design
- ✅ PRD-to-SQL automation
- ✅ Real-time validation with PGLite
- ✅ Automated test generation with pgTAP
- ✅ Schema versioning and history
- ✅ Interactive ERD visualization
- ✅ GitHub integration
- ✅ Production-ready PostgreSQL DDL
- ✅ Self-correcting agent workflows

**Get started:**
```bash
./ACTIONS/setup.sh
./ACTIONS/start.sh
```

**Test it:**
```
Type: "Create a blog system with users and posts"
```

**Happy schema designing! 🎨✨**

