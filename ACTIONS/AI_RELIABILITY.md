# 🤖 AI Provider Reliability Guide

Complete guide for configuring and monitoring AI provider reliability features in Liam.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Configuration](#configuration)
4. [Monitoring](#monitoring)
5. [Troubleshooting](#troubleshooting)
6. [Best Practices](#best-practices)

---

## 🎯 Overview

Liam includes production-grade AI reliability features to handle provider failures gracefully:

### Key Features

**🔄 Provider Fallback**
- Automatically switch to backup provider on failure
- Supports OpenAI → Anthropic fallback
- Configurable fallback triggers

**⚡ Exponential Backoff Retry**
- Retry transient failures automatically
- Smart backoff: 1s, 2s, 4s delays
- Includes jitter to prevent thundering herd

**🚨 Circuit Breaker Pattern**
- Fail fast after repeated failures
- Automatic recovery testing
- Prevents cascading failures

**📊 Error Classification**
- Intelligent error categorization
- Determines retry strategy per error type
- Rate limit, timeout, auth error handling

**📈 Metrics & Monitoring**
- Request/response latency tracking
- Success/failure rates
- Provider health monitoring

---

## ⚡ Quick Start

### Basic Configuration

Enable AI reliability with fallback:

```typescript
// frontend/internal-packages/agent/src/config/aiConfig.ts
import { createResilientChatModel } from '../ai-reliability'

export const createChatModel = () => {
  return createResilientChatModel({
    // Primary provider (required)
    primary: {
      provider: 'openai',
      model: 'gpt-4',
      timeout: 30000,
    },
    
    // Fallback provider (recommended)
    fallback: {
      provider: 'anthropic',
      model: 'claude-3-sonnet-20240229',
      timeout: 30000,
    },
    
    // Enable all reliability features
    enableCircuitBreaker: true,
    enableRetry: true,
    enableLogging: true,
  })
}
```

### Environment Variables

Add to `.env.local`:

```bash
# Primary provider
OPENAI_API_KEY=sk-...

# Fallback provider (optional but recommended)
ANTHROPIC_API_KEY=sk-ant-...

# Reliability configuration (optional)
AI_RELIABILITY_ENABLED=true
AI_MAX_RETRIES=3
AI_RETRY_DELAY_MS=1000
AI_CIRCUIT_BREAKER_THRESHOLD=5
AI_CIRCUIT_BREAKER_TIMEOUT_MS=60000
```

---

## ⚙️ Configuration

### Provider Configuration

**OpenAI (Primary)**
```typescript
{
  provider: 'openai',
  model: 'gpt-4' | 'gpt-4-turbo' | 'gpt-3.5-turbo',
  apiKey: process.env['OPENAI_API_KEY'],
  baseURL: process.env['OPENAI_BASE_URL'], // Optional: for custom endpoints
  timeout: 30000, // 30 seconds
}
```

**Anthropic (Fallback)**
```typescript
{
  provider: 'anthropic',
  model: 'claude-3-sonnet-20240229' | 'claude-3-opus-20240229',
  apiKey: process.env['ANTHROPIC_API_KEY'],
  baseURL: process.env['ANTHROPIC_BASE_URL'], // Optional
  timeout: 30000,
}
```

**Custom Provider (Z.AI, Azure, etc.)**
```typescript
{
  provider: 'custom',
  model: 'gpt-4',
  apiKey: 'your-api-key',
  baseURL: 'https://api.z.ai/api/openai', // Required for custom
  timeout: 30000,
}
```

### Retry Configuration

```typescript
{
  enableRetry: true,
  maxRetries: 3, // Total attempts = 1 initial + 3 retries
  retryDelayMs: 1000, // Initial delay (doubled each retry)
}
```

**Retry behavior:**
- Attempt 1: Immediate
- Attempt 2: Wait 1s (with ±25% jitter)
- Attempt 3: Wait 2s (with ±25% jitter)
- Attempt 4: Wait 4s (with ±25% jitter)

**Automatically retries:**
- ✅ Timeout errors
- ✅ 500/502/503/504 server errors
- ✅ Connection reset errors
- ✅ Unknown transient errors

**Does NOT retry:**
- ❌ Rate limit errors (uses fallback instead)
- ❌ Authentication errors (401/403)
- ❌ Invalid request errors (400/422)

### Circuit Breaker Configuration

```typescript
{
  enableCircuitBreaker: true,
  circuitBreakerThreshold: 5, // Open circuit after 5 consecutive failures
  circuitBreakerTimeout: 60000, // Test recovery after 60 seconds
}
```

**Circuit states:**
1. **CLOSED** (normal): All requests pass through
2. **OPEN** (failing): Requests fail immediately, fallback used
3. **HALF_OPEN** (testing): Single test request allowed

**State transitions:**
```
CLOSED --[5 failures]--> OPEN
OPEN --[60s timeout]--> HALF_OPEN
HALF_OPEN --[success]--> CLOSED
HALF_OPEN --[failure]--> OPEN
```

### Logging Configuration

```typescript
{
  enableLogging: true, // Enable request/response logging
  logger: (message, data) => {
    console.log(message, JSON.stringify(data, null, 2))
  },
}
```

**Logged events:**
- `request_start` - Request initiated
- `request_success` - Request completed
- `request_failure` - Request failed
- `retry` - Retry attempt
- `fallback_attempt` - Switching to fallback
- `fallback_failure` - Fallback also failed

---

## 📊 Monitoring

### Metrics Endpoint

Add to health check API:

```typescript
// frontend/apps/app/app/api/metrics/route.ts
import { chatModel } from '@/config/aiConfig'

export async function GET() {
  const metrics = chatModel.getMetrics()
  
  return Response.json({
    ai_providers: {
      primary: {
        provider: metrics.primary.provider,
        model: metrics.primary.model,
        total_requests: metrics.primary.totalRequests,
        successful_requests: metrics.primary.successfulRequests,
        failed_requests: metrics.primary.failedRequests,
        success_rate: metrics.primary.totalRequests > 0
          ? (metrics.primary.successfulRequests / metrics.primary.totalRequests * 100).toFixed(2) + '%'
          : 'N/A',
        avg_latency_ms: Math.round(metrics.primary.avgLatencyMs),
        last_error: metrics.primary.lastError?.message,
      },
      fallback: metrics.fallback ? {
        provider: metrics.fallback.provider,
        model: metrics.fallback.model,
        total_requests: metrics.fallback.totalRequests,
        successful_requests: metrics.fallback.successfulRequests,
        failed_requests: metrics.fallback.failedRequests,
        success_rate: metrics.fallback.totalRequests > 0
          ? (metrics.fallback.successfulRequests / metrics.fallback.totalRequests * 100).toFixed(2) + '%'
          : 'N/A',
        avg_latency_ms: Math.round(metrics.fallback.avgLatencyMs),
      } : null,
      circuit_breakers: {
        primary: metrics.circuitBreakers.primary,
        fallback: metrics.circuitBreakers.fallback,
      },
    },
  })
}
```

### Monitoring Dashboard

Query metrics endpoint:

```bash
curl http://localhost:3001/api/metrics

# Output:
{
  "ai_providers": {
    "primary": {
      "provider": "openai",
      "model": "gpt-4",
      "total_requests": 150,
      "successful_requests": 148,
      "failed_requests": 2,
      "success_rate": "98.67%",
      "avg_latency_ms": 2340,
      "last_error": null
    },
    "fallback": {
      "provider": "anthropic",
      "model": "claude-3-sonnet-20240229",
      "total_requests": 2,
      "successful_requests": 2,
      "failed_requests": 0,
      "success_rate": "100.00%",
      "avg_latency_ms": 1890
    },
    "circuit_breakers": {
      "primary": {
        "state": "CLOSED",
        "failureCount": 0,
        "threshold": 5
      },
      "fallback": {
        "state": "CLOSED",
        "failureCount": 0,
        "threshold": 5
      }
    }
  }
}
```

### Alerting

**Set up alerts for:**

1. **High failure rate** (> 10%)
   ```bash
   if [ $(curl -s http://localhost:3001/api/metrics | jq -r '.ai_providers.primary.failed_requests / .ai_providers.primary.total_requests * 100') -gt 10 ]; then
     # Send alert
   fi
   ```

2. **Circuit breaker OPEN**
   ```bash
   if [ $(curl -s http://localhost:3001/api/metrics | jq -r '.ai_providers.circuit_breakers.primary.state') == "OPEN" ]; then
     # Send alert: Primary provider is down
   fi
   ```

3. **High latency** (> 5s avg)
   ```bash
   if [ $(curl -s http://localhost:3001/api/metrics | jq -r '.ai_providers.primary.avg_latency_ms') -gt 5000 ]; then
     # Send alert: Slow responses
   fi
   ```

---

## 🔧 Troubleshooting

### Provider Always Using Fallback

**Symptoms:**
- All requests go to fallback provider
- Primary circuit breaker shows OPEN

**Diagnosis:**
```bash
curl http://localhost:3001/api/metrics | jq '.ai_providers.circuit_breakers.primary'
```

**Causes:**
1. Primary provider API key invalid
2. Primary provider rate limited
3. Primary provider endpoint unreachable

**Solutions:**
1. Check API key: `echo $OPENAI_API_KEY`
2. Verify quota: Check provider dashboard
3. Test endpoint: `curl https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_API_KEY"`
4. Manually reset circuit: See [Resetting Circuit Breaker](#resetting-circuit-breaker)

### High Latency

**Symptoms:**
- Requests taking > 5 seconds
- Users experiencing slow responses

**Diagnosis:**
```bash
curl http://localhost:3001/api/metrics | jq '.ai_providers.primary.avg_latency_ms'
```

**Causes:**
1. Model selection (GPT-4 slower than GPT-3.5)
2. Network latency
3. Provider overload

**Solutions:**
1. Switch to faster model (GPT-4-turbo or GPT-3.5-turbo)
2. Increase timeout: `timeout: 60000` in config
3. Use fallback provider if consistently slow

### Rate Limit Errors

**Symptoms:**
- Errors: "Rate limit exceeded" or 429 status
- Frequent fallback usage

**Diagnosis:**
```bash
curl http://localhost:3001/api/metrics | jq '.ai_providers.primary.last_error'
```

**Causes:**
1. High request volume exceeding quota
2. Multiple instances sharing same API key
3. Spike in traffic

**Solutions:**
1. Upgrade provider plan
2. Use separate API keys per environment
3. Implement request queuing/throttling
4. Rely on fallback provider during spikes

### Resetting Circuit Breaker

If circuit breaker is stuck OPEN but provider is healthy:

```typescript
// Add to admin endpoint
import { chatModel } from '@/config/aiConfig'

export async function POST(request: Request) {
  const { action } = await request.json()
  
  if (action === 'reset_circuit_breakers') {
    chatModel.reset()
    return Response.json({ success: true })
  }
}
```

```bash
curl -X POST http://localhost:3001/api/admin/reset-circuit-breakers \
  -H "Content-Type: application/json" \
  -d '{"action":"reset_circuit_breakers"}'
```

---

## ✅ Best Practices

### 1. Always Configure Fallback Provider

```typescript
// ✅ Good: Fallback configured
{
  primary: { provider: 'openai', model: 'gpt-4' },
  fallback: { provider: 'anthropic', model: 'claude-3-sonnet' },
}

// ❌ Bad: No fallback
{
  primary: { provider: 'openai', model: 'gpt-4' },
}
```

**Why:** Single provider = single point of failure

### 2. Use Different Providers for Primary/Fallback

```typescript
// ✅ Good: Different providers
primary: { provider: 'openai', ... }
fallback: { provider: 'anthropic', ... }

// ❌ Bad: Same provider
primary: { provider: 'openai', model: 'gpt-4' }
fallback: { provider: 'openai', model: 'gpt-3.5-turbo' }
```

**Why:** Provider-wide outages affect all models

### 3. Set Appropriate Timeouts

```typescript
// ✅ Good: Reasonable timeout
timeout: 30000 // 30 seconds

// ❌ Bad: Too short
timeout: 5000 // 5 seconds - will timeout frequently

// ❌ Bad: Too long
timeout: 120000 // 2 minutes - users will wait too long
```

**Recommended timeouts:**
- GPT-4: 30-45 seconds
- GPT-3.5-turbo: 15-30 seconds
- Claude: 30-45 seconds

### 4. Enable Logging in Development

```typescript
// Development
enableLogging: process.env['NODE_ENV'] === 'development'

// Production (use structured logging)
logger: (message, data) => {
  logger.info(message, { ...data, service: 'ai-reliability' })
}
```

### 5. Monitor Metrics Regularly

Set up dashboard or alerts for:
- Success rate < 95%
- Avg latency > 3 seconds
- Circuit breaker OPEN
- Fallback usage > 5%

### 6. Test Failure Scenarios

```typescript
// Test with invalid API key
primary: { apiKey: 'invalid-key' }

// Test with unreachable endpoint
primary: { baseURL: 'https://invalid-endpoint.example.com' }

// Verify fallback works correctly
```

### 7. Separate API Keys by Environment

```bash
# Development
OPENAI_API_KEY=sk-dev-...

# Staging
OPENAI_API_KEY=sk-staging-...

# Production
OPENAI_API_KEY=sk-prod-...
```

**Why:** Prevents quota exhaustion, easier debugging

---

## 🚨 Common Scenarios

### Scenario 1: Provider Outage

**What happens:**
1. Primary requests start failing
2. After 5 failures, circuit breaker opens
3. All subsequent requests use fallback
4. After 60s, circuit tests recovery
5. If recovered, circuit closes

**User impact:** Minimal - automatic fallback

### Scenario 2: Rate Limit Hit

**What happens:**
1. Rate limit error detected
2. Immediate fallback (no retry)
3. Primary circuit breaker NOT opened
4. System continues on fallback

**User impact:** None - seamless switch

### Scenario 3: Transient Network Error

**What happens:**
1. Request fails with timeout
2. Retry after 1s (with jitter)
3. If still fails, retry after 2s
4. If still fails, retry after 4s
5. If all retries fail, use fallback

**User impact:** Slight delay (max 7s before fallback)

---

## 📚 Additional Resources

- [Deployment Guide](../DEPLOYMENT.md)
- [Security Guide](SECURITY.md)
- [Health Check Endpoints](examples/docker-healthcheck.yml)
- [Monitoring Setup](../DEPLOYMENT.md#monitoring--maintenance)

---

**Questions?** Open an issue on GitHub or check the documentation.

