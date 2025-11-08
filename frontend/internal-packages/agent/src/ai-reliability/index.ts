/**
 * AI Reliability Module
 * 
 * Provides production-grade reliability patterns for AI provider integrations:
 * - Provider fallback mechanisms
 * - Exponential backoff retry logic
 * - Circuit breaker pattern
 * - Request/response logging
 * - Error classification and handling
 */

export { createResilientChatModel } from './resilientChatModel'
export { CircuitBreaker, CircuitBreakerState } from './circuitBreaker'
export { retryWithBackoff, type RetryConfig } from './retryWithBackoff'
export { AIProviderError, ErrorCategory, classifyError } from './errorClassification'
export type { AIProvider, ProviderConfig, ResilientModelOptions } from './types'

