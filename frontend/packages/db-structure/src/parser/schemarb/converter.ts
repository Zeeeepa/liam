import type { Columns, DBStructure, Table } from 'src/schema'

// biome-ignore lint/suspicious/noExplicitAny: TODO: Generate types with pegjs
export const convertToDBStructure = (data: any): DBStructure => {
  return {
    // biome-ignore lint/suspicious/noExplicitAny: TODO: Generate types with pegjs
    tables: data.tables.reduce((acc: Record<string, Table>, table: any) => {
      const columns: Columns = {}
      for (const field of table.fields) {
        columns[field.name] = {
          check: null,
          comment: null,
          default: 'default' in field ? field.default : null,
          increment: false,
          name: field.name,
          notNull: 'nullable' in field ? !field.nullable : false,
          primary: field.PK || false,
          type: field.type.type_name,
          unique: false,
        }
      }

      acc[table.name] = {
        comment: null,
        columns,
        indices: [],
        name: table.name,
      }
      return acc
    }, {}),
    relationships: {},
  }
}
