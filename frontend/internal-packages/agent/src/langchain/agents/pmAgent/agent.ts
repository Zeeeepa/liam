import * as v from 'valibot'
import { BaseGeminiAgent, type GeminiAgentConfig } from '../base/geminiAgent'
import { mapOpenAIModelToGemini } from '../../utils/geminiConfig'
import type { BasePromptVariables } from '../../utils/types'
import { PMAgentMode, pmAnalysisPrompt, pmReviewPrompt } from './prompts'

interface PMAgentVariables extends BasePromptVariables {
  requirements_analysis?: string
  proposed_changes?: string
}

export const requirementsAnalysisSchema = v.object({
  businessRequirement: v.string(),
  functionalRequirements: v.record(v.string(), v.array(v.string())),
  nonFunctionalRequirements: v.record(v.string(), v.array(v.string())),
})

export class PMAgent extends BaseGeminiAgent {
  constructor(config?: GeminiAgentConfig) {
    // Use Gemini equivalent of o3 for project management tasks
    const geminiConfig = {
      model: mapOpenAIModelToGemini('o3'),
      ...config,
    }
    super(geminiConfig)
  }

  async generate(variables: BasePromptVariables): Promise<string> {
    // Default to analysis mode for backward compatibility
    return this.generateWithMode(variables, PMAgentMode.ANALYSIS)
  }

  async generateWithMode(
    variables: PMAgentVariables,
    mode: PMAgentMode,
  ): Promise<string> {
    const prompt =
      mode === PMAgentMode.ANALYSIS ? pmAnalysisPrompt : pmReviewPrompt

    const formattedPrompt = await prompt.format(variables)
    const response = await this.model.invoke(formattedPrompt)
    return response.content as string
  }

  // Convenience methods
  async analyzeRequirements(
    variables: BasePromptVariables,
  ): Promise<v.InferOutput<typeof requirementsAnalysisSchema>> {
    const response = await this.generateWithMode(
      variables,
      PMAgentMode.ANALYSIS,
    )
    const parsedResponse = JSON.parse(response)
    return v.parse(requirementsAnalysisSchema, parsedResponse)
  }

  async reviewDeliverables(variables: PMAgentVariables): Promise<string> {
    return this.generateWithMode(variables, PMAgentMode.REVIEW)
  }
}
