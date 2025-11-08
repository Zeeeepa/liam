/**
 * Resilient Chat Model Wrapper
 * Wraps LangChain chat models with production-grade reliability
 */

import type { AIMessageChunk, BaseMessage } from '@langchain/core/messages'
import { ChatAnthropic } from '@langchain/anthropic'
import { ChatOpenAI } from '@langchain/openai'
import { CircuitBreaker } from './circuitBreaker'
import { classifyError } from './errorClassification'
import { retryWithBackoff } from './retryWithBackoff'
import type { AIProvider, ModelMetrics, ProviderConfig, ResilientModelOptions } from './types'

export class ResilientChatModel {
  private primaryModel: ChatOpenAI | ChatAnthropic
  private fallbackModel: (ChatOpenAI | ChatAnthropic) | null = null
  private primaryCircuitBreaker: CircuitBreaker | null = null
  private fallbackCircuitBreaker: CircuitBreaker | null = null
  private readonly options: Required<ResilientModelOptions>
  private metrics: { primary: ModelMetrics; fallback: ModelMetrics | null }
  
  constructor(options: ResilientModelOptions) {
    this.options = {
      ...options,
      enableCircuitBreaker: options.enableCircuitBreaker ?? true,
      circuitBreakerThreshold: options.circuitBreakerThreshold ?? 5,
      circuitBreakerTimeout: options.circuitBreakerTimeout ?? 60000,
      enableRetry: options.enableRetry ?? true,
      maxRetries: options.maxRetries ?? 3,
      retryDelayMs: options.retryDelayMs ?? 1000,
      enableLogging: options.enableLogging ?? false,
      logger: options.logger ?? console.log,
    }
    
    this.primaryModel = this.createModel(options.primary)
    if (options.fallback) {
      this.fallbackModel = this.createModel(options.fallback)
    }
    
    if (this.options.enableCircuitBreaker) {
      this.primaryCircuitBreaker = new CircuitBreaker(
        this.options.circuitBreakerThreshold,
        this.options.circuitBreakerTimeout,
        `${options.primary.provider}-${options.primary.model}`,
      )
      if (this.fallbackModel) {
        this.fallbackCircuitBreaker = new CircuitBreaker(
          this.options.circuitBreakerThreshold,
          this.options.circuitBreakerTimeout,
          `${options.fallback!.provider}-${options.fallback!.model}`,
        )
      }
    }
    
    this.metrics = {
      primary: this.createMetrics(options.primary),
      fallback: options.fallback ? this.createMetrics(options.fallback) : null,
    }
  }
  
  private createModel(config: ProviderConfig): ChatOpenAI | ChatAnthropic {
    switch (config.provider) {
      case 'openai':
        return new ChatOpenAI({
          model: config.model,
          apiKey: config.apiKey || process.env['OPENAI_API_KEY'],
          configuration: config.baseURL ? { baseURL: config.baseURL } : undefined,
          timeout: config.timeout,
          maxRetries: 0,
        })
      case 'anthropic':
        return new ChatAnthropic({
          model: config.model,
          apiKey: config.apiKey || process.env['ANTHROPIC_API_KEY'],
          clientOptions: config.baseURL ? { baseURL: config.baseURL } : undefined,
          timeout: config.timeout,
          maxRetries: 0,
        })
      case 'custom':
        return new ChatOpenAI({
          model: config.model,
          apiKey: config.apiKey,
          configuration: config.baseURL ? { baseURL: config.baseURL } : undefined,
          timeout: config.timeout,
          maxRetries: 0,
        })
      default:
        throw new Error(`Unsupported provider: ${config.provider}`)
    }
  }
  
  private createMetrics(config: ProviderConfig): ModelMetrics {
    return {
      provider: config.provider,
      model: config.model,
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      totalLatencyMs: 0,
      avgLatencyMs: 0,
      lastRequestTime: null,
      lastError: null,
    }
  }
  
  async stream(messages: BaseMessage[], options?: Record<string, unknown>): Promise<AsyncIterable<AIMessageChunk>> {
    return this.executeWithReliability(
      async (model) => model.stream(messages, options),
      'primary',
    )
  }
  
  private async executeWithReliability<T>(
    fn: (model: ChatOpenAI | ChatAnthropic) => Promise<T>,
    providerType: 'primary' | 'fallback',
  ): Promise<T> {
    const startTime = Date.now()
    const isPrimary = providerType === 'primary'
    const model = isPrimary ? this.primaryModel : this.fallbackModel!
    const circuitBreaker = isPrimary ? this.primaryCircuitBreaker : this.fallbackCircuitBreaker
    const metrics = isPrimary ? this.metrics.primary : this.metrics.fallback!
    const config = isPrimary ? this.options.primary : this.options.fallback!
    
    const executeRequest = async (): Promise<T> => {
      const execute = circuitBreaker
        ? () => circuitBreaker.execute(() => fn(model))
        : () => fn(model)
      
      if (this.options.enableRetry) {
        return retryWithBackoff(execute, {
          maxRetries: this.options.maxRetries,
          initialDelayMs: this.options.retryDelayMs,
          shouldRetry: (error) => classifyError(error, config.provider).retryable,
          onRetry: (attempt, error) => {
            this.log('retry', { provider: config.provider, attempt, error: error.message })
          },
        })
      }
      return execute()
    }
    
    try {
      this.log('request_start', { provider: config.provider, type: providerType })
      const result = await executeRequest()
      
      const latency = Date.now() - startTime
      metrics.totalRequests++
      metrics.successfulRequests++
      metrics.totalLatencyMs += latency
      metrics.avgLatencyMs = metrics.totalLatencyMs / metrics.totalRequests
      metrics.lastRequestTime = new Date()
      
      this.log('request_success', { provider: config.provider, latencyMs: latency })
      return result
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error))
      const classified = classifyError(err, config.provider)
      
      metrics.totalRequests++
      metrics.failedRequests++
      metrics.lastError = classified
      metrics.lastRequestTime = new Date()
      
      this.log('request_failure', { provider: config.provider, error: classified.message })
      
      if (isPrimary && this.fallbackModel) {
        this.log('fallback_attempt', { from: config.provider, to: this.options.fallback!.provider })
        try {
          return await this.executeWithReliability(fn, 'fallback')
        } catch (fallbackError) {
          this.log('fallback_failure', { provider: this.options.fallback!.provider })
          throw classified
        }
      }
      
      throw classified
    }
  }
  
  getMetrics() {
    return {
      primary: { ...this.metrics.primary },
      fallback: this.metrics.fallback ? { ...this.metrics.fallback } : null,
      circuitBreakers: {
        primary: this.primaryCircuitBreaker?.getState() || null,
        fallback: this.fallbackCircuitBreaker?.getState() || null,
      },
    }
  }
  
  reset() {
    this.primaryCircuitBreaker?.reset()
    this.fallbackCircuitBreaker?.reset()
    this.metrics.primary = this.createMetrics(this.options.primary)
    if (this.options.fallback) {
      this.metrics.fallback = this.createMetrics(this.options.fallback)
    }
  }
  
  getModel(): ChatOpenAI | ChatAnthropic {
    return this.primaryModel
  }
  
  private log(event: string, data?: Record<string, unknown>) {
    if (this.options.enableLogging) {
      this.options.logger(`[ResilientChatModel] ${event}`, data)
    }
  }
}

export const createResilientChatModel = (options: ResilientModelOptions): ResilientChatModel => {
  return new ResilientChatModel(options)
}
