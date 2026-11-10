import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
// Puerto fijo 5180 (el 5173 lo usa otra aplicación). Debe coincidir con
// app.cors.allowed-origins del backend.
export default defineConfig({
  plugins: [react()],
  server: { port: 5180, strictPort: true },
  preview: { port: 5180, strictPort: true },
})
