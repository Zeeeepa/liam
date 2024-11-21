import { type DBStructure, dbStructureSchema } from '@liam/db-structure/dist/index.js'
import { ERDRenderer } from '@liam/erd-core/src/index.js'
import { useEffect, useState } from 'react'
import * as v from 'valibot'

function App() {
  const [schemaJsonContent, setSchemaJsonContent] =
    useState<DBStructure | null>(null)

  useEffect(() => {
    async function loadSchemaContent() {
      try {
        const response = await fetch('/schema.json')
        if (!response.ok) {
          throw new Error(`Failed to fetch schema: ${response.statusText}`)
        }
        const data = await response.json()
        const result = v.safeParse(dbStructureSchema, data)
        result.success
          ? setSchemaJsonContent(result.output)
          : console.info(result.issues)

        // This is a temporary workaround.
        // For demo purposes, we ignore the validation result and set the schema content directly.
        // TODO: remove this line.
        setSchemaJsonContent(data)
      } catch (error) {
        console.error('Error loading schema content:', error)
      }
    }

    loadSchemaContent()
  }, [])

  return (
    <>{schemaJsonContent && <ERDRenderer dbStructure={schemaJsonContent} />}</>
  )
}

export default App
