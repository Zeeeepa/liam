import type { BaseChatModel } from '@langchain/core/language_models/chat_models'

export type AIProvider = 'openai' | 'anthropic' | 'custom'

export interface ProviderConfig {
  provider: AIProvider
  model: string
  apiKey?: string
  baseURL?: string
  timeout?: number
  maxRetries?: number
}

export interface ResilientModelOptions {
  /** Primary provider configuration */
  primary: ProviderConfig
  
  /** Fallback provider configuration (optional) */
  fallback?: ProviderConfig
  
  /** Enable circuit breaker (default: true) */
  enableCircuitBreaker?: boolean
  
  /** Circuit breaker failure threshold (default: 5) */
  circuitBreakerThreshold?: number
  
  /** Circuit breaker timeout in ms (default: 60000) */
  circuitBreakerTimeout?: number
  
  /** Enable retry with exponential backoff (default: true) */
  enableRetry?: boolean
  
  /** Maximum retry attempts (default: 3) */
  maxRetries?: number
  
  /** Initial retry delay in ms (default: 1000) */
  retryDelayMs?: number
  
  /** Enable request/response logging (default: false) */
  enableLogging?: boolean
  
  /** Custom logger function */
  logger?: (message: string, data?: Record<string, unknown>) => void
}

export interface ModelMetrics {
  provider: AIProvider
  model: string
  totalRequests: number
  successfulRequests: number
  failedRequests: number
  totalLatencyMs: number
  avgLatencyMs: number
  lastRequestTime: Date | null
  lastError: Error | null
}

