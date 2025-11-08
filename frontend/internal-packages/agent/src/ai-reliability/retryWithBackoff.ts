/**
 * Retry with Exponential Backoff
 */

export interface RetryConfig {
  maxRetries: number
  initialDelayMs: number
  maxDelayMs?: number
  shouldRetry?: (error: Error) => boolean
  onRetry?: (attempt: number, error: Error) => void
}

const DEFAULT_MAX_DELAY_MS = 30000

export const retryWithBackoff = async <T>(
  fn: () => Promise<T>,
  config: RetryConfig,
): Promise<T> => {
  const { maxRetries, initialDelayMs, maxDelayMs = DEFAULT_MAX_DELAY_MS, shouldRetry, onRetry } = config
  let lastError: Error | undefined
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn()
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error))
      
      if (attempt === maxRetries || (shouldRetry && !shouldRetry(lastError))) {
        throw lastError
      }
      
      const exponentialDelay = initialDelayMs * Math.pow(2, attempt)
      const cappedDelay = Math.min(exponentialDelay, maxDelayMs)
      const jitter = cappedDelay * 0.25 * (Math.random() - 0.5)
      const delay = Math.max(0, cappedDelay + jitter)
      
      onRetry?.(attempt + 1, lastError)
      await new Promise((resolve) => setTimeout(resolve, delay))
    }
  }
  
  throw lastError
}
