/**
 * Error Classification for AI Provider Failures
 */

export enum ErrorCategory {
  RATE_LIMIT = 'RATE_LIMIT',
  TIMEOUT = 'TIMEOUT',
  AUTHENTICATION = 'AUTHENTICATION',
  INVALID_REQUEST = 'INVALID_REQUEST',
  TRANSIENT = 'TRANSIENT',
  UNKNOWN = 'UNKNOWN',
}

export class AIProviderError extends Error {
  constructor(
    message: string,
    public readonly category: ErrorCategory,
    public readonly provider: string,
    public readonly statusCode?: number,
    public readonly retryable: boolean = true,
  ) {
    super(message)
    this.name = 'AIProviderError'
  }
}

export const classifyError = (error: Error, provider: string): AIProviderError => {
  const message = error.message.toLowerCase()
  const statusCode = extractStatusCode(error)
  
  // Rate limit errors
  if (statusCode === 429 || message.includes('rate limit')) {
    return new AIProviderError(error.message, ErrorCategory.RATE_LIMIT, provider, statusCode, false)
  }
  
  // Timeout errors
  if (message.includes('timeout') || message.includes('timed out')) {
    return new AIProviderError(error.message, ErrorCategory.TIMEOUT, provider, statusCode, true)
  }
  
  // Authentication errors
  if (statusCode === 401 || statusCode === 403 || message.includes('unauthorized')) {
    return new AIProviderError(error.message, ErrorCategory.AUTHENTICATION, provider, statusCode, false)
  }
  
  // Invalid request errors
  if (statusCode === 400 || statusCode === 422) {
    return new AIProviderError(error.message, ErrorCategory.INVALID_REQUEST, provider, statusCode, false)
  }
  
  // Transient errors
  if (statusCode === 500 || statusCode === 502 || statusCode === 503 || statusCode === 504) {
    return new AIProviderError(error.message, ErrorCategory.TRANSIENT, provider, statusCode, true)
  }
  
  return new AIProviderError(error.message, ErrorCategory.UNKNOWN, provider, statusCode, true)
}

const extractStatusCode = (error: Error): number | undefined => {
  const anyError = error as any
  if (anyError.status) return anyError.status
  if (anyError.statusCode) return anyError.statusCode
  if (anyError.response?.status) return anyError.response.status
  return undefined
}
