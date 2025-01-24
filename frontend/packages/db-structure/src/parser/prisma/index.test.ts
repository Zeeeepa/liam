import { describe, expect, it } from 'vitest'
import { parserTestCases } from '../__tests__/testcase.js'
import { processor as _processor } from './index.js'

const prismaSchemaHeader = `
  generator client {
    provider = "prisma-client-js"
  }

  datasource db {
    provider = "postgresql"
    url = env("DATABASE_URL")
  }
`

const processor = async (schema: string) =>
  _processor(`${prismaSchemaHeader}\n\n${schema}`)

describe('Prisma Schema Parser', () => {
  Object.entries(parserTestCases).forEach(
    ([testCaseName, expectedStructure]) => {
      it(`should correctly parse ${testCaseName}`, async () => {
        const prismaSchema = generatePrismaSchema(testCaseName)
        const { value } = await processor(prismaSchema)
        expect(value).toEqual(expectedStructure)
      })
    },
  )
})

function generatePrismaSchema(testCase: string): string {
  switch (testCase) {
    case 'table comment':
      return '/// store our users.\nmodel users {\n  id Int @id @default(autoincrement())\n}'
    case 'column comment':
      return 'model users {\n  id Int @id @default(autoincrement())\n  /// this is description\n  description String?\n}'
    case 'not null':
      return 'model users {\n  id Int @id @default(autoincrement())\n  name String\n}'
    case 'nullable':
      return 'model users {\n  id Int @id @default(autoincrement())\n  description String?\n}'
    case 'default value as string':
      return `model users {\n  id Int @id @default(autoincrement())\n  description String @default("user's description")\n}`
    case 'default value as integer':
      return 'model users {\n  id Int @id @default(autoincrement())\n  age Int @default(30)\n}'
    case 'default value as boolean':
      return 'model users {\n  id Int @id @default(autoincrement())\n  active Boolean @default(true)\n}'
    case 'unique':
      return 'model users {\n  id Int @id @default(autoincrement())\n  mention String @unique\n}'
    case 'index (unique: false)':
      return 'model users {\n  id Int @id @default(autoincrement())\n  email String\n  @@index([id, email])\n}'
    case 'index (unique: true)':
      return 'model users {\n  id Int @id @default(autoincrement())\n  email String\n  @@unique([id, email])\n}'
    case 'foreign key (one-to-many)':
      return 'model users {\n  id Int @id @default(autoincrement())\n  posts posts[]\n}\nmodel posts {\n  id Int @id @default(autoincrement())\n  user users @relation(fields: [user_id], references: [id])\n  user_id Int\n}'
    case 'foreign key (one-to-one)':
      return 'model users {\n  id Int @id @default(autoincrement())\n  post posts?\n}\nmodel posts {\n  id Int @id @default(autoincrement())\n  user users @relation(fields: [user_id], references: [id])\n  user_id Int @unique\n}'
    case 'foreign key with action':
      return 'model posts {\n  id Int @id @default(autoincrement())\n  user users @relation(fields: [user_id], references: [id], onDelete: CASCADE)\n  user_id Int\n}'
    default:
      throw new Error(`Test case ${testCase} not implemented.`)
  }
}
