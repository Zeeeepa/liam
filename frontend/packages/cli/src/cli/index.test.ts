import type { Command } from 'commander'
import { describe, expect, it, vi } from 'vitest'
import { program } from '.'
import { buildCommand } from './commands'

// Function to set up mocks
function setupMocks() {
  vi.mock('./commands/buildCommand', () => ({
    buildCommand: vi.fn(),
  }))
}

// Utility function to find a subcommand
function findSubCommand(erdCommand: Command | undefined, name: string) {
  return erdCommand?.commands.find((cmd: Command) => cmd.name() === name)
}

setupMocks()

describe('program', () => {
  it('should have the correct name and description', () => {
    expect(program.name()).toBe('liam')
    expect(program.description()).toBe('CLI tool for Liam')
  })

  it('should have an "erd" command with subcommands', () => {
    const erdCommand = program.commands.find((cmd) => cmd.name() === 'erd')
    expect(erdCommand).toBeDefined()
    expect(erdCommand?.description()).toBe('ERD commands')

    // Verify subcommands
    const buildSubCommand = findSubCommand(erdCommand, 'build')
    expect(buildSubCommand).toBeDefined()
    expect(buildSubCommand?.description()).toBe('Run Vite build')
  })

  describe('commands', () => {
    it('should call buildCommand when "build" command is executed', () => {
      program.parse(['erd', 'build', '--input', 'path/to/file.sql'], {
        from: 'user',
      })
      expect(buildCommand).toHaveBeenCalledWith(
        'path/to/file.sql',
        expect.stringMatching(/\/dist$/),
      )
    })
  })
})
