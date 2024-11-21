import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, expect, it } from 'vitest'
import { runPreprocess } from './runPreprocess'

describe('runPreprocess', () => {
  it('should create schema.json with the SQL content in the specified directory', () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'test-distDir-'))
    const inputPath = path.join(tmpDir, 'input.sql')

    const sqlContent = 'CREATE TABLE test (id INT, name VARCHAR(255));'
    fs.writeFileSync(inputPath, sqlContent, 'utf8')

    const outputFilePath = runPreprocess(inputPath, tmpDir)
    if (!outputFilePath) throw new Error('Implement the test')

    expect(fs.existsSync(outputFilePath)).toBe(true)

    const outputContent = JSON.parse(fs.readFileSync(outputFilePath, 'utf8'))
    expect(outputContent.tables).toBeDefined()
  })

  it('should throw an error if the input file does not exist', () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'test-distDir-'))
    const nonExistentPath = path.join(tmpDir, 'non-existent.sql')

    expect(() => runPreprocess(nonExistentPath, tmpDir)).toThrow(
      'Invalid input path. Please provide a valid file.',
    )
  })
})
