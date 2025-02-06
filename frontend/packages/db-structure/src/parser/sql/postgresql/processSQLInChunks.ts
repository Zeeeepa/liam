/**
 * Processes a large SQL input string in chunks (by line count)
 *
 * @param input - The large SQL input string to be processed.
 * @param chunkSize - The number of lines to include in each chunk (e.g., 500).
 * @param callback - An asynchronous callback function that processes each chunk.
 */
export const processSQLInChunks = async (
  input: string,
  chunkSize: number,
  callback: (chunk: string) => Promise<[number | null, number | null]>,
): Promise<void> => {
  const lines = input.split('\n')

  let trySize = 0
  for (let i = 0; i < lines.length; ) {
    trySize = chunkSize
    let looping = true
    let strategy = -1

    while (looping) {
      const chunk = lines.slice(i, i + trySize).join('\n')

      const [errorPosition, readPosition] = await callback(chunk)

      if (errorPosition !== null) {
        if (strategy === -1) {
          trySize--
          if (trySize === 0) {
            strategy = 1
            trySize = chunkSize + 1
          }
        } else if (strategy === 1) {
          trySize++
        }
      } else if (readPosition !== null) {
        const lineno = getLineNumber(chunk, readPosition)
        i += lineno || trySize
        looping = false
      } else {
        i += trySize
        looping = false
      }
    }
  }
}

function getLineNumber(s: string, n: number): number | null {
  if (n < 0 || n >= s.length) return null

  let line = 1
  let count = 0

  for (const char of s) {
    if (count === n) return line
    if (char === '\n') line++
    count++
  }

  return null
}
