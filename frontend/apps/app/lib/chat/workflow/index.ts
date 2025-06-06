import { LangGraphWorkflow } from './services/langGraphWorkflow'
import { executeStreamingWorkflow } from './streaming/streamingWorkflow'
import type { ResponseChunk, WorkflowOptions, WorkflowState } from './types'

/**
 * Unified workflow execution function with overloads for type safety
 */
export function executeChatWorkflow(
  initialState: WorkflowState,
): AsyncGenerator<ResponseChunk, WorkflowState, unknown>
export function executeChatWorkflow(
  initialState: WorkflowState,
  options: WorkflowOptions & { streaming: true },
): AsyncGenerator<ResponseChunk, WorkflowState, unknown>
export function executeChatWorkflow(
  initialState: WorkflowState,
  options: WorkflowOptions & { streaming: false },
): Promise<WorkflowState>
export function executeChatWorkflow(
  initialState: WorkflowState,
  options?: WorkflowOptions,
):
  | Promise<WorkflowState>
  | AsyncGenerator<ResponseChunk, WorkflowState, unknown> {
  const streaming = options?.streaming ?? true // Default to streaming
  const recursionLimit = options?.recursionLimit ?? 10

  if (streaming === false) {
    return LangGraphWorkflow(initialState, recursionLimit)
  }

  return executeStreamingWorkflow(initialState)
}
