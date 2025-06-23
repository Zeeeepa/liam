import { operationsSchema } from '@liam-hq/db-structure'
import { toJsonSchema } from '@valibot/to-json-schema'
import * as v from 'valibot'
import { BaseGeminiAgent, type GeminiAgentConfig } from '../base/geminiAgent'
import { mapOpenAIModelToGemini } from '../../utils/geminiConfig'
import type { BasePromptVariables } from '../../utils/types'
import { buildAgentPrompt } from './prompts'

// Define the response schema
const buildAgentResponseSchema = v.object({
  message: v.string(),
  schemaChanges: operationsSchema,
})

export type BuildAgentResponse = v.InferOutput<typeof buildAgentResponseSchema>

export class DatabaseSchemaBuildAgent extends BaseGeminiAgent<BuildAgentResponse> {
  private structuredModel: ReturnType<typeof this.model.withStructuredOutput>

  constructor(config?: GeminiAgentConfig) {
    // Use Gemini equivalent of o3 for database schema building
    const geminiConfig = {
      model: mapOpenAIModelToGemini('o3'),
      ...config,
    }
    super(geminiConfig)

    // Convert valibot schema to JSON Schema and bind to model
    // FIXME: operationsSchema contains v.custom() which cannot be converted to JSON Schema
    // This causes "The 'custom' schema cannot be converted to JSON Schema" error
    // Need to find alternative approach for custom validation in structured outputs
    const jsonSchema = toJsonSchema(buildAgentResponseSchema, {
      errorMode: 'ignore',
    })
    this.structuredModel = this.withStructuredOutput(jsonSchema)
  }

  async generate(variables: BasePromptVariables): Promise<BuildAgentResponse> {
    const formattedPrompt = await buildAgentPrompt.format(variables)
    const rawResponse = await this.structuredModel.invoke(formattedPrompt)

    return v.parse(buildAgentResponseSchema, rawResponse)
  }
}
