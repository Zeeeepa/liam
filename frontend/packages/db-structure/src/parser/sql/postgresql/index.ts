import type { DBStructure } from '../../../schema/index.js'
import type { ProcessError } from '../../errors.js'
import type { Processor } from '../../types.js'
import { convertToDBStructure } from './converter.js'
import { mergeDBStructures } from './mergeDBStructures.js'
import { parse } from './parser.js'
import { processSQLInChunks } from './processSQLInChunks.js'

export const processor: Processor = async (str: string) => {
  const dbStructure: DBStructure = { tables: {}, relationships: {} }
  const CHUNK_SIZE = 500
  const errors: ProcessError[] = []

  await processSQLInChunks(str, CHUNK_SIZE, async (chunk) => {
    let readPosition: number | null = null
    let errorPosition: number | null = null
    const { parse_tree, error: parseError } = await parse(chunk)

    if (parse_tree.stmts.length > 0) {
      if (parseError !== null) {
        throw new Error('UnexpectedCondition')
      }
    }

    if (parseError !== null) {
      errorPosition = parseError.cursorpos
      // TODO: save error message
      return [errorPosition, readPosition]
    }

    let lastStmtCompleted = true
    const l = parse_tree.stmts.length
    if (l > 0) {
      const last = parse_tree.stmts[l - 1]
      if (last?.stmt_len === undefined) {
        lastStmtCompleted = false
        if (last?.stmt_location === undefined) {
          throw new Error('UnexpectedCondition')
        }
        readPosition = last?.stmt_location - 1
      }
    }

    const { value: converted, errors: convertErrors } = convertToDBStructure(
      lastStmtCompleted ? parse_tree.stmts : parse_tree.stmts.slice(0, -1),
    )
    if (convertErrors !== null) {
      errors.push(...convertErrors)
    }

    mergeDBStructures(dbStructure, converted)

    return [errorPosition, readPosition]
  })

  return { value: dbStructure, errors }
}
