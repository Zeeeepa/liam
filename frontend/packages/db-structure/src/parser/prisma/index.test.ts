import { describe, expect, it } from 'vitest'
import type { Table } from '../../schema/index.js'
import { aColumn, aDBStructure, aTable, anIndex } from '../../schema/index.js'
import { processor as _processor } from './index.js'

describe(_processor, () => {
  const userTable = (override?: Partial<Table>) =>
    aDBStructure({
      tables: {
        users: aTable({
          name: 'users',
          columns: {
            id: aColumn({
              name: 'id',
              type: 'Int',
              notNull: true,
              primary: true,
              unique: false,
            }),
            ...override?.columns,
          },
          indices: {
            users_pkey: anIndex({
              name: 'users_pkey',
              unique: true,
              columns: ['id'],
            }),
            ...override?.indices,
          },
          comment: override?.comment ?? null,
        }),
      },
    })

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

  describe('should parse prisma schema correctly', () => {
    it('not null', async () => {
      const { value } = await processor(`
        model users {
          id   Int    @id @default(autoincrement())
          name String
        }
      `)

      const expected = userTable({
        columns: {
          name: aColumn({
            name: 'name',
            type: 'String',
            notNull: true,
          }),
        },
      })

      expect(value).toEqual(expected)
    })

    it('nullable', async () => {
      const { value } = await processor(`
        model users {
          id   Int    @id @default(autoincrement())
          description String?
        }
      `)

      const expected = userTable({
        columns: {
          description: aColumn({
            name: 'description',
            type: 'String',
            notNull: false,
          }),
        },
      })

      expect(value).toEqual(expected)
    })

    it('default value as string', async () => {
      const { value } = await processor(`
        model users {
          id   Int    @id @default(autoincrement())
          description String @default("user's description")
        }
      `)

      const expected = userTable({
        columns: {
          description: aColumn({
            name: 'description',
            type: 'String',
            default: "user's description",
            notNull: true,
          }),
        },
      })

      expect(value).toEqual(expected)
    })

    it('default value as integer', async () => {
      const { value } = await processor(`
        model users {
          id   Int    @id @default(autoincrement())
          age  Int    @default(30)
        }
      `)

      const expected = userTable({
        columns: {
          age: aColumn({
            name: 'age',
            type: 'Int',
            default: 30,
            notNull: true,
          }),
        },
      })

      expect(value).toEqual(expected)
    })

    it('default value as boolean', async () => {
      const { value } = await processor(`
        model users {
          id     Int     @id @default(autoincrement())
          active Boolean @default(true)
        }
      `)

      const expected = userTable({
        columns: {
          active: aColumn({
            name: 'active',
            type: 'Boolean',
            default: true,
            notNull: true,
          }),
        },
      })

      expect(value).toEqual(expected)
    })

    it('column comment', async () => {
      const { value } = await processor(`
        model users {
          id   Int    @id @default(autoincrement())
          /// this is description
          description String?
        }
      `)

      const expected = userTable({
        columns: {
          description: aColumn({
            name: 'description',
            type: 'String',
            comment: 'this is description',
          }),
        },
      })

      expect(value).toEqual(expected)
    })

    it('table comment', async () => {
      const { value } = await processor(`
        /// store our users.
        model users {
          id   Int    @id @default(autoincrement())
        }
      `)

      const expected = userTable({
        comment: 'store our users.',
      })

      expect(value).toEqual(expected)
    })

    it('index (unique: false)', async () => {
      const { value } = await processor(`
        model users {
          id   Int    @id @default(autoincrement())
          email String
          @@index([id, email])
        }
      `)

      const expected = userTable({
        columns: {
          email: aColumn({
            name: 'email',
            type: 'String',
            notNull: true,
          }),
        },
        indices: {
          users_id_email_idx: anIndex({
            name: 'users_id_email_idx',
            unique: false,
            columns: ['id', 'email'],
          }),
        },
      })

      expect(value).toEqual(expected)
    })

    it('index (unique: true)', async () => {
      const { value } = await processor(`
        model users {
          id   Int    @id @default(autoincrement())
          email String
          @@unique([id, email])
        }
      `)

      const expected = userTable({
        columns: {
          email: aColumn({
            name: 'email',
            type: 'String',
            notNull: true,
          }),
        },
        indices: {
          users_pkey: anIndex({
            name: 'users_pkey',
            unique: true,
            columns: ['id'],
          }),
          users_id_email_key: anIndex({
            name: 'users_id_email_key',
            unique: true,
            columns: ['id', 'email'],
          }),
        },
      })

      expect(value).toEqual(expected)
    })

    it('relationship (one-to-many)', async () => {
      const { value } = await processor(`
        model users {
          id   Int    @id @default(autoincrement())
          posts posts[]
        }

        model posts {
          id   Int    @id @default(autoincrement())
          user users @relation(fields: [user_id], references: [id])
          user_id Int
        }
      `)

      const expected = {
        postsTousers: {
          name: 'postsTousers',
          primaryTableName: 'users',
          primaryColumnName: 'id',
          foreignTableName: 'posts',
          foreignColumnName: 'user_id',
          cardinality: 'ONE_TO_MANY',
          updateConstraint: 'NO_ACTION',
          deleteConstraint: 'NO_ACTION',
        },
      }

      expect(value.relationships).toEqual(expected)
    })

    it('relationship (one-to-one)', async () => {
      const { value } = await processor(`
        model users {
          id   Int    @id @default(autoincrement())
          post posts?
        }

        model posts {
          id      Int    @id @default(autoincrement())
          user    users  @relation(fields: [user_id], references: [id])
          user_id Int    @unique
        }
      `)

      const expected = {
        postsTousers: {
          name: 'postsTousers',
          primaryTableName: 'users',
          primaryColumnName: 'id',
          foreignTableName: 'posts',
          foreignColumnName: 'user_id',
          cardinality: 'ONE_TO_ONE',
          updateConstraint: 'NO_ACTION',
          deleteConstraint: 'NO_ACTION',
        },
      }

      expect(value.relationships).toEqual(expected)
    })

    describe('foreign key constraints (on delete)', () => {
      const constraintCases = [
        ['Cascade', 'CASCADE'],
        ['Restrict', 'RESTRICT'],
        ['NoAction', 'NO_ACTION'],
        ['SetNull', 'SET_NULL'],
        ['SetDefault', 'SET_DEFAULT'],
      ] as const

      it.each(constraintCases)(
        'on delete %s',
        async (prismaAction: string, expectedAction: string) => {
          const { value } = await processor(`
          model users {
            id   Int    @id @default(autoincrement())
            posts posts[]
          }

          model posts {
            id   Int    @id @default(autoincrement())
            user users @relation(fields: [user_id], references: [id], onDelete: ${prismaAction})
            user_id Int
          }
        `)

          const expected = {
            postsTousers: {
              name: 'postsTousers',
              primaryTableName: 'users',
              primaryColumnName: 'id',
              foreignTableName: 'posts',
              foreignColumnName: 'user_id',
              cardinality: 'ONE_TO_MANY',
              updateConstraint: 'NO_ACTION',
              deleteConstraint: expectedAction,
            },
          }

          expect(value.relationships).toEqual(expected)
        },
      )
    })

    it('columns do not include model type', async () => {
      const { value } = await processor(`
        model users {
          id   Int    @id @default(autoincrement())
          posts posts[]
        }

        model posts {
          id   Int    @id @default(autoincrement())
          user users @relation(fields: [user_id], references: [id])
          user_id Int
        }
      `)

      // biome-ignore lint/complexity/useLiteralKeys: for readability and simplicity
      const usersTable = value.tables['users']
      // biome-ignore lint/complexity/useLiteralKeys: for readability and simplicity
      const postsTable = value.tables['posts']

      if (!usersTable || !usersTable.columns) {
        throw new Error('Users table or columns are undefined')
      }
      if (!postsTable || !postsTable.columns) {
        throw new Error('Posts table or columns are undefined')
      }

      const usersColumnNames = Object.keys(usersTable.columns)
      const postsColumnNames = Object.keys(postsTable.columns)

      expect(usersColumnNames).toEqual(['id'])
      expect(usersColumnNames).not.toContain('posts')
      expect(postsColumnNames).toEqual(['id', 'user_id'])
      expect(postsColumnNames).not.toContain('user')
    })

    it('unique', async () => {
      const { value } = await processor(`
        model users {
          id   Int    @id @default(autoincrement())
          email String @unique
        }
      `)

      const expected = userTable({
        columns: {
          email: aColumn({
            name: 'email',
            type: 'String',
            notNull: true,
            unique: true,
          }),
        },
        indices: {
          users_email_key: anIndex({
            name: 'users_email_key',
            unique: true,
            columns: ['email'],
          }),
        },
      })

      expect(value).toEqual(expected)
    })

    it('not unique', async () => {
      const { value } = await processor(`
        model users {
          id   Int    @id @default(autoincrement())
          email String
        }
      `)

      const expected = userTable({
        columns: {
          email: aColumn({
            name: 'email',
            type: 'String',
            notNull: true,
            unique: false,
          }),
        },
      })

      expect(value).toEqual(expected)
    })
  })
})
