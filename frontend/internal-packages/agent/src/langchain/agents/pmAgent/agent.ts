import * as v from 'valibot'
import { BaseGeminiAgent } from '../base/geminiAgent'
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
  constructor() {
    // Configure Gemini 2.0 Flash for PM tasks with higher creativity
    super({
      model: 'gemini-2.0-flash-exp',
      temperature: 0.2, // Slightly higher for creative requirement analysis
      maxOutputTokens: 8192,
    })
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
    const validatedPrompt = this.validateAndFormatPrompt(formattedPrompt)
    
    return this.invokeModel(validatedPrompt)
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
