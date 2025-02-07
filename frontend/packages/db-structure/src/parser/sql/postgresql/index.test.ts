import { describe, expect, it } from 'vitest'
import type { Table } from '../../../schema/index.js'
import { aColumn, aDBStructure, aTable } from '../../../schema/index.js'
import { createParserTestCases } from '../../__tests__/index.js'
import { UnexpectedTokenWarningError } from '../../errors.js'
import { processor } from './index.js'

describe(processor, () => {
  const userTable = (override?: Partial<Table>) =>
    aDBStructure({
      tables: {
        users: aTable({
          name: 'users',
          columns: {
            id: aColumn({
              name: 'id',
              type: 'bigserial',
              notNull: true,
              primary: true,
              unique: true,
            }),
            ...override?.columns,
          },
          indices: {
            ...override?.indices,
          },
          comment: override?.comment ?? null,
        }),
      },
    })
  const parserTestCases = createParserTestCases(userTable)

  describe('should parse CREATE TABLE statement correctly', () => {
    it('table comment', async () => {
      const { value } = await processor(/* sql */ `
        CREATE TABLE users (
          id BIGSERIAL PRIMARY KEY
        );
        COMMENT ON TABLE users IS 'store our users.';
      `)

      expect(value).toEqual(parserTestCases['table comment'])
    })
  })
})
