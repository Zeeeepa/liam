import type {
  Cardinality,
  Columns,
  Constraints,
  ForeignKeyConstraintReferenceOption,
  Indexes,
  Relationship,
  TableGroup,
  Tables,
} from '../../schema/index.js'
import { aColumn, anIndex, aRelationship, aTable } from '../../schema/index.js'
import type { Processor, ProcessResult } from '../types.js'
import { defaultRelationshipName } from '../utils/index.js'
import schema from './schema.generated.js'

function extractCardinality(cardinality: string): Cardinality {
  if (cardinality === 'zero_or_one') {
    return 'ONE_TO_ONE'
  }
  if (cardinality === 'zero_or_more') {
    return 'ONE_TO_MANY'
  }
  if (cardinality === 'one_or_more') {
    return 'ONE_TO_MANY'
  }
  return 'ONE_TO_MANY'
}

const FK_ACTIONS = 'SET NULL|SET DEFAULT|RESTRICT|CASCADE|NO ACTION'

function extractForeignKeyActions(def: string): {
  updateConstraint: ForeignKeyConstraintReferenceOption
  deleteConstraint: ForeignKeyConstraintReferenceOption
} {
  const defaultAction: ForeignKeyConstraintReferenceOption = 'NO_ACTION'
  const actions: {
    updateConstraint: ForeignKeyConstraintReferenceOption
    deleteConstraint: ForeignKeyConstraintReferenceOption
  } = {
    updateConstraint: defaultAction,
    deleteConstraint: defaultAction,
  }

  const updateMatch = def.match(new RegExp(`ON UPDATE (${FK_ACTIONS})`))
  if (updateMatch?.[1]) {
    actions.updateConstraint = normalizeConstraintName(
      updateMatch[1].toLowerCase(),
    )
  }

  const deleteMatch = def.match(new RegExp(`ON DELETE (${FK_ACTIONS})`))
  if (deleteMatch?.[1]) {
    actions.deleteConstraint = normalizeConstraintName(
      deleteMatch[1].toLowerCase(),
    )
  }

  return actions
}

function normalizeConstraintName(
  constraint: string,
): ForeignKeyConstraintReferenceOption {
  switch (constraint) {
    case 'cascade':
      return 'CASCADE'
    case 'restrict':
      return 'RESTRICT'
    case 'set null':
      return 'SET_NULL'
    case 'set default':
      return 'SET_DEFAULT'
    default:
      return 'NO_ACTION'
  }
}

/**
 * Extract unique column names from constraints
 */
function extractUniqueColumnNames(
  constraints:
    | Array<{
        type: string
        name: string
        columns?: string[]
        def: string
        referenced_table?: string
        referenced_columns?: string[]
      }>
    | undefined,
): Set<string> {
  const uniqueColumns: string[] = []

  if (constraints) {
    const uniqueConstraints = constraints.filter(
      (constraint) =>
        constraint.type === 'UNIQUE' && constraint.columns?.length === 1,
    )

    for (const constraint of uniqueConstraints) {
      if (constraint.columns?.[0]) {
        uniqueColumns.push(constraint.columns[0])
      }
    }
  }

  return new Set(uniqueColumns)
}

/**
 * Extract primary key column names from constraints
 */
function extractPrimaryKeyColumnNames(
  constraints:
    | Array<{
        type: string
        name: string
        columns?: string[]
        def: string
        referenced_table?: string
        referenced_columns?: string[]
      }>
    | undefined,
): Set<string> {
  const primaryKeyColumns: string[] = []

  if (constraints) {
    const primaryKeyConstraints = constraints.filter(
      (constraint) => constraint.type === 'PRIMARY KEY',
    )

    for (const constraint of primaryKeyConstraints) {
      if (constraint.columns) {
        primaryKeyColumns.push(...constraint.columns)
      }
    }
  }

  return new Set(primaryKeyColumns)
}

/**
 * Process columns for a table
 */
function processColumns(
  tblsColumns: Array<{
    name: string
    type: string
    nullable: boolean
    default?: string | null
    comment?: string | null
  }>,
  uniqueColumnNames: Set<string>,
  primaryKeyColumnNames: Set<string>,
): Columns {
  const columns: Columns = {}

  for (const tblsColumn of tblsColumns) {
    const defaultValue = extractDefaultValue(tblsColumn.default)

    columns[tblsColumn.name] = aColumn({
      name: tblsColumn.name,
      type: tblsColumn.type,
      notNull: !tblsColumn.nullable,
      default: defaultValue,
      primary: primaryKeyColumnNames.has(tblsColumn.name),
      comment: tblsColumn.comment ?? null,
      unique: uniqueColumnNames.has(tblsColumn.name),
    })
  }

  return columns
}

/**
 * Process a PRIMARY KEY constraint
 */
function processPrimaryKeyConstraint(constraint: {
  type: string
  name: string
  columns?: string[]
  def: string
  referenced_table?: string
  referenced_columns?: string[]
}): [string, Constraints[string]] | null {
  if (
    constraint.type === 'PRIMARY KEY' &&
    constraint.columns?.length === 1 &&
    constraint.columns?.[0]
  ) {
    return [
      constraint.name,
      {
        type: 'PRIMARY KEY',
        name: constraint.name,
        columnName: constraint.columns[0],
      },
    ]
  }

  return null
}

/**
 * Process a FOREIGN KEY constraint
 */
function processForeignKeyConstraint(constraint: {
  type: string
  name: string
  columns?: string[]
  def: string
  referenced_table?: string
  referenced_columns?: string[]
}): [string, Constraints[string]] | null {
  if (
    constraint.type === 'FOREIGN KEY' &&
    constraint.columns?.length === 1 &&
    constraint.columns[0] &&
    constraint.referenced_columns?.length === 1 &&
    constraint.referenced_columns[0] &&
    constraint.referenced_table
  ) {
    const { updateConstraint, deleteConstraint } = extractForeignKeyActions(
      constraint.def,
    )

    return [
      constraint.name,
      {
        type: 'FOREIGN KEY',
        name: constraint.name,
        columnName: constraint.columns[0],
        targetTableName: constraint.referenced_table,
        targetColumnName: constraint.referenced_columns[0],
        updateConstraint,
        deleteConstraint,
      },
    ]
  }

  return null
}

/**
 * Process a UNIQUE constraint
 */
function processUniqueConstraint(constraint: {
  type: string
  name: string
  columns?: string[]
  def: string
  referenced_table?: string
  referenced_columns?: string[]
}): [string, Constraints[string]] | null {
  if (
    constraint.type === 'UNIQUE' &&
    constraint.columns?.length === 1 &&
    constraint.columns[0]
  ) {
    return [
      constraint.name,
      {
        type: 'UNIQUE',
        name: constraint.name,
        columnName: constraint.columns[0],
      },
    ]
  }

  return null
}

/**
 * Process a CHECK constraint
 */
function processCheckConstraint(constraint: {
  type: string
  name: string
  columns?: string[]
  def: string
  referenced_table?: string
  referenced_columns?: string[]
}): [string, Constraints[string]] | null {
  if (constraint.type === 'CHECK') {
    return [
      constraint.name,
      {
        type: 'CHECK',
        name: constraint.name,
        detail: constraint.def,
      },
    ]
  }

  return null
}

/**
 * Process constraints for a table
 */
function processConstraints(
  tblsConstraints:
    | Array<{
        type: string
        name: string
        columns?: string[]
        def: string
        referenced_table?: string
        referenced_columns?: string[]
      }>
    | undefined,
): Constraints {
  const constraints: Constraints = {}

  if (!tblsConstraints) {
    return constraints
  }

  for (const constraint of tblsConstraints) {
    let result: [string, Constraints[string]] | null = null

    // Process different constraint types
    if (constraint.type === 'PRIMARY KEY') {
      result = processPrimaryKeyConstraint(constraint)
    } else if (constraint.type === 'FOREIGN KEY') {
      result = processForeignKeyConstraint(constraint)
    } else if (constraint.type === 'UNIQUE') {
      result = processUniqueConstraint(constraint)
    } else if (constraint.type === 'CHECK') {
      result = processCheckConstraint(constraint)
    }

    // Add constraint to the collection if valid
    if (result) {
      constraints[result[0]] = result[1]
    }
  }

  return constraints
}

/**
 * Process indexes for a table
 */
function processIndexes(
  tblsIndexes:
    | Array<{
        name: string
        def: string
        columns: string[]
      }>
    | undefined,
): Indexes {
  const indexes: Indexes = {}

  if (!tblsIndexes) {
    return indexes
  }

  for (const tblsIndex of tblsIndexes) {
    indexes[tblsIndex.name] = anIndex({
      name: tblsIndex.name,
      columns: tblsIndex.columns,
      unique: tblsIndex.def.toLowerCase().includes('unique'),
      type: tblsIndex.def.toLocaleLowerCase().match(/using\s+(\w+)/)?.[1] || '',
    })
  }

  return indexes
}

/**
 * Process a single table
 */
function processTable(tblsTable: {
  name: string
  columns: Array<{
    name: string
    type: string
    nullable: boolean
    default?: string | null
    comment?: string | null
  }>
  constraints?: Array<{
    type: string
    name: string
    columns?: string[]
    def: string
    referenced_table?: string
    referenced_columns?: string[]
  }>
  indexes?: Array<{
    name: string
    def: string
    columns: string[]
  }>
  comment?: string | null
}): [string, Tables[string]] {
  // Extract column metadata
  const uniqueColumnNames = extractUniqueColumnNames(tblsTable.constraints)
  const primaryKeyColumnNames = extractPrimaryKeyColumnNames(
    tblsTable.constraints,
  )

  // Process table components
  const columns = processColumns(
    tblsTable.columns,
    uniqueColumnNames,
    primaryKeyColumnNames,
  )
  const constraints = processConstraints(tblsTable.constraints)
  const indexes = processIndexes(tblsTable.indexes)

  // Create the table
  return [
    tblsTable.name,
    aTable({
      name: tblsTable.name,
      columns,
      indexes,
      constraints,
      comment: tblsTable.comment ?? null,
    }),
  ]
}

/**
 * Process relationships from relations
 */
function processRelationships(
  relations:
    | Array<{
        table: string
        columns: string[]
        parent_table: string
        parent_columns: string[]
        def: string
        cardinality?: string
      }>
    | undefined,
): Record<string, Relationship> {
  const relationships: Record<string, Relationship> = {}

  if (!relations) {
    return relationships
  }

  for (const relation of relations) {
    if (!relation.parent_columns[0] || !relation.columns[0]) {
      continue
    }

    const name = defaultRelationshipName(
      relation.parent_table,
      relation.parent_columns[0],
      relation.table,
      relation.columns[0],
    )

    const actions = extractForeignKeyActions(relation.def)

    relationships[name] = aRelationship({
      name,
      primaryTableName: relation.parent_table,
      primaryColumnName: relation.parent_columns[0],
      foreignTableName: relation.table,
      foreignColumnName: relation.columns[0],
      cardinality: extractCardinality(relation.cardinality ?? ''),
      deleteConstraint: actions.deleteConstraint,
      updateConstraint: actions.updateConstraint,
    })
  }

  return relationships
}

/**
 * Main function to parse a tbls schema
 */
async function parseTblsSchema(schemaString: string): Promise<ProcessResult> {
  // Parse the schema
  const parsedSchema = JSON.parse(schemaString)
  const result = schema.safeParse(parsedSchema)

  // Handle invalid schema
  if (!result.success) {
    return {
      value: {
        tables: {},
        relationships: {},
        tableGroups: {},
      },
      errors: [new Error(`Invalid schema format: ${result.error}`)],
    }
  }

  // Initialize collections
  const tables: Tables = {}
  const tableGroups: Record<string, TableGroup> = {}
  const errors: Error[] = []

  // Define compatible types for type assertions
  type CompatibleTable = {
    name: string
    columns: Array<{
      name: string
      type: string
      nullable: boolean
      default?: string | null
      comment?: string | null
    }>
    constraints?: Array<{
      type: string
      name: string
      columns?: string[]
      def: string
      referenced_table?: string
      referenced_columns?: string[]
    }>
    indexes?: Array<{
      name: string
      def: string
      columns: string[]
    }>
    comment?: string | null
  }

  type CompatibleRelation = {
    table: string
    columns: string[]
    parent_table: string
    parent_columns: string[]
    def: string
    cardinality?: string
  }

  // Process tables
  for (const tblsTable of result.data.tables) {
    // Use type assertion with a specific type
    const [tableName, table] = processTable(tblsTable as CompatibleTable)
    tables[tableName] = table
  }

  // Process relationships
  const relationships = processRelationships(
    result.data.relations as CompatibleRelation[],
  )

  // Return the schema
  return {
    value: {
      tables,
      relationships,
      tableGroups,
    },
    errors,
  }
}

function extractDefaultValue(
  value: string | null | undefined,
): Columns[string]['default'] {
  if (value === null || value === undefined) {
    return null
  }

  // Convert string to number if it represents a number
  if (!Number.isNaN(Number(value))) {
    return Number(value)
  }

  // Convert string to boolean if it represents a boolean
  if (value.toLowerCase() === 'true') {
    return true
  }
  if (value.toLowerCase() === 'false') {
    return false
  }

  return value
}

export const processor: Processor = (str) => parseTblsSchema(str)
