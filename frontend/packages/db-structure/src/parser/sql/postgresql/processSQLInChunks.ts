/**
 * Processes a large SQL input string in chunks (by line count)
 *
 * @param sqlInput - The SQL input string to be processed.
 * @param chunkSize - The number of lines per chunk (e.g., 500).
 * @param callback - An asynchronous function to process each chunk.
 */
export const processSQLInChunks = async (
  sqlInput: string,
  chunkSize: number,
  callback: (chunk: string) => Promise<[number | null, number | null]>,
): Promise<void> => {
  if (sqlInput === '') return
  const lines = sqlInput.split('\n')
  let currentChunkSize = 0

  for (let i = 0; i < lines.length; ) {
    console.error('Error processing')
    currentChunkSize = chunkSize
    let retryProcessing = true
    let retryStrategy = -1

    while (retryProcessing) {
      console.error('Error processing6')
      const chunk = lines.slice(i, i + currentChunkSize).join('\n')
      const [errorOffset, readOffset] = await callback(chunk)

      if (errorOffset !== null) {
        if (retryStrategy === -1) {
          currentChunkSize--
          if (currentChunkSize === 0) {
            retryStrategy = 1
            currentChunkSize = chunkSize
          }
        } else if (retryStrategy === 1) {
          currentChunkSize++
          console.error('Error processing2')
          throw new Error(currentChunkSize.toString())
        }
      } else if (readOffset !== null) {
        const lineNumber = getLineNumber(chunk, readOffset)
        i += lineNumber || currentChunkSize
        console.error('Error processing3')
        retryProcessing = false
      } else {
        i += currentChunkSize
        console.error('Error processing4')
        console.error(currentChunkSize)
        console.error(chunk)
        retryProcessing = false
      }
    }
  }
}

/**
 * Determines the line number in a string corresponding to a given character index.
 *
 * @param inputString - The string to search within.
 * @param charIndex - The character index.
 * @returns The line number, or null if the index is out of bounds.
 */
function getLineNumber(inputString: string, charIndex: number): number | null {
  if (charIndex < 0 || charIndex >= inputString.length) return null

  let lineNumber = 1
  let currentIndex = 0

  for (const char of inputString) {
    if (currentIndex === charIndex) return lineNumber
    if (char === '\n') lineNumber++
    currentIndex++
  }

  return null
}
