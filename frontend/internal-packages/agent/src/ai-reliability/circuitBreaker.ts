/**
 * Circuit Breaker Pattern for AI Provider Protection
 */

export enum CircuitBreakerState {
  CLOSED = 'CLOSED',
  OPEN = 'OPEN',
  HALF_OPEN = 'HALF_OPEN',
}

export class CircuitBreaker {
  private state: CircuitBreakerState = CircuitBreakerState.CLOSED
  private failureCount = 0
  private lastFailureTime: Date | null = null
  private nextAttemptTime: Date | null = null
  
  constructor(
    private readonly threshold: number,
    private readonly timeoutMs: number,
    private readonly name: string = 'default',
  ) {}
  
  async execute<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === CircuitBreakerState.OPEN) {
      if (this.nextAttemptTime && new Date() >= this.nextAttemptTime) {
        this.state = CircuitBreakerState.HALF_OPEN
        console.log(`Circuit breaker [${this.name}]: OPEN -> HALF_OPEN`)
      } else {
        throw new Error(`Circuit breaker [${this.name}] is OPEN`)
      }
    }
    
    try {
      const result = await fn()
      this.onSuccess()
      return result
    } catch (error) {
      this.onFailure()
      throw error
    }
  }
  
  private onSuccess(): void {
    this.failureCount = 0
    this.lastFailureTime = null
    if (this.state === CircuitBreakerState.HALF_OPEN) {
      this.state = CircuitBreakerState.CLOSED
      console.log(`Circuit breaker [${this.name}]: HALF_OPEN -> CLOSED`)
    }
  }
  
  private onFailure(): void {
    this.failureCount++
    this.lastFailureTime = new Date()
    
    if (this.state === CircuitBreakerState.HALF_OPEN || this.failureCount >= this.threshold) {
      this.openCircuit()
    }
  }
  
  private openCircuit(): void {
    this.state = CircuitBreakerState.OPEN
    this.nextAttemptTime = new Date(Date.now() + this.timeoutMs)
    console.warn(`Circuit breaker [${this.name}]: -> OPEN (failures: ${this.failureCount})`)
  }
  
  reset(): void {
    this.state = CircuitBreakerState.CLOSED
    this.failureCount = 0
    this.lastFailureTime = null
    this.nextAttemptTime = null
    console.log(`Circuit breaker [${this.name}]: manually reset`)
  }
  
  getState() {
    return {
      state: this.state,
      failureCount: this.failureCount,
      lastFailureTime: this.lastFailureTime,
      nextAttemptTime: this.nextAttemptTime,
      threshold: this.threshold,
      timeoutMs: this.timeoutMs,
    }
  }
}
