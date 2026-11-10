import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  // Nothing is inlined as data: URLs, so the strict content security policy holds.
  build: { target: 'es2020', chunkSizeWarningLimit: 900, assetsInlineLimit: 0, sourcemap: false },
})
