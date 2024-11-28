import type { Constraint, CreateStmt, Node } from '@pgsql/types'
import type { Columns, DBStructure, Table } from 'src/schema'
import type { RawStmtWrapper } from './parser'

// Transform function for AST to DBStructure
export const convertToDBStructure = (ast: RawStmtWrapper[]): DBStructure => {
  const tables: Record<string, Table> = {}

  // Creating a new variable str to hold the returned string value,
  // as it's not a property of the String type.
  interface PgString {
    sval: string
    str: string
  }

  function isStringNode(node: Node): node is { String: PgString } {
    return (
      'String' in node &&
      typeof node.String === 'object' &&
      node.String !== null &&
      'str' in node.String &&
      node.String.str !== 'pg_catalog'
    )
  }

  function isConstraintNode(node: Node): node is { Constraint: Constraint } {
    return (node as { Constraint: Constraint }).Constraint !== undefined
  }

  function isCreateStmt(stmt: Node): stmt is { CreateStmt: CreateStmt } {
    return 'CreateStmt' in stmt
  }

  if (!ast) {
    return {
      tables: {},
      relationships: {},
    }
  }

  // @ts-expect-error
  for (const statement of ast.parse_tree.stmts) {
    if (statement?.stmt === undefined) continue
    const stmt = statement.stmt
    if (isCreateStmt(stmt)) {
      const createStmt = stmt.CreateStmt
      if (!createStmt || !createStmt.relation || !createStmt.tableElts) continue
      const tableName = createStmt.relation.relname
      const columns: Columns = {}
      for (const elt of createStmt.tableElts) {
        if ('ColumnDef' in elt) {
          const colDef = elt.ColumnDef
          columns[colDef.colname || ''] = {
            name: colDef.colname || '',
            type:
              colDef.typeName?.names
                ?.filter(isStringNode)
                .map((n) => n.String.str)
                .join('') || '',
            default: null, // TODO
            check: null, // TODO
            primary:
              colDef.constraints
                ?.filter(isConstraintNode)
                .some((c) => c.Constraint.contype === 'CONSTR_PRIMARY') ||
              false,
            unique:
              colDef.constraints
                ?.filter(isConstraintNode)
                .some((c) => c.Constraint.contype === 'CONSTR_UNIQUE') || false,
            notNull:
              colDef.constraints
                ?.filter(isConstraintNode)
                .some((c) => c.Constraint.contype === 'CONSTR_NOTNULL') ||
              // If primary key, it's not null
              colDef.constraints
                ?.filter(isConstraintNode)
                .some((c) => c.Constraint.contype === 'CONSTR_PRIMARY') ||
              false,
            increment:
              colDef.typeName?.names
                ?.filter(isStringNode)
                .some((n) => n.String.sval === 'serial') || false,
            comment: null, // TODO
          }
        }
      }

      if (tableName) {
        tables[tableName] = {
          name: tableName,
          columns,
          comment: null, // TODO
          indices: [], // TODO
        }
      }
    }
  }

  return {
    tables,
    relationships: {},
  }
}
