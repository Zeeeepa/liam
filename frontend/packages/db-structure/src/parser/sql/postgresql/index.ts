import { err } from 'neverthrow'
import type { DBStructure } from '../../../schema/index.js'
import type { ProcessError } from '../../errors.js'
import type { Processor } from '../../types.js'
import { convertToDBStructure } from './converter.js'
import { mergeDBStructures } from './mergeDBStructures.js'
import { parse } from './parser.js'
import { processSQLInChunks } from './processSQLInChunks.js'

/**
 * Processes SQL statements and constructs a database structure.
 */
export const processor: Processor = async (sql: string) => {
  const dbSchema: DBStructure = { tables: {}, relationships: {} }
  const CHUNK_SIZE = 500
  const parseErrors: ProcessError[] = []

  await processSQLInChunks(sql, CHUNK_SIZE, async (chunk) => {
    let readOffset: number | null = null
    let errorOffset: number | null = null

    const { parse_tree, error: parseError } = await parse(chunk)

    if (parse_tree.stmts.length > 0 && parseError !== null) {
      throw new Error('UnexpectedCondition')
    }

    if (parseError !== null) {
      errorOffset = parseError.cursorpos
      // TODO: Store error message for reporting
      return [errorOffset, readOffset]
    }

    let isLastStatementComplete = true
    const statementCount = parse_tree.stmts.length

    if (statementCount > 0) {
      const lastStmt = parse_tree.stmts[statementCount - 1]
      if (lastStmt?.stmt_len === undefined) {
        isLastStatementComplete = false
        if (lastStmt?.stmt_location === undefined) {
          throw new Error('UnexpectedCondition')
        }
        readOffset = lastStmt?.stmt_location - 1
      }
    }

    const { value: convertedSchema, errors: conversionErrors } =
      convertToDBStructure(
        isLastStatementComplete
          ? parse_tree.stmts
          : parse_tree.stmts.slice(0, -1),
      )

    if (conversionErrors !== null) {
      parseErrors.push(...conversionErrors)
    }

    mergeDBStructures(dbSchema, convertedSchema)

    return [errorOffset, readOffset]
  })

  return { value: dbSchema, errors: parseErrors }
}
