import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  build: {
    chunkSizeWarningLimit: 1600,
    rollupOptions: {
      external: ['@liam/db-structure', '@liam/erd-core'],
    },
  },
  plugins: [react()],
})
