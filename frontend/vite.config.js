import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// Versão do app: um lugar só, o FastAPI(version=...) do backend/app/main.py. A tela compila com ela e compara com o
// cabeçalho X-App-Versao das respostas para avisar quando o servidor foi atualizado.
const versao = readFileSync(new URL('../backend/app/main.py', import.meta.url), 'utf-8').match(/FastAPI\([^)]*version="([^"]+)"/)?.[1]
if (!versao) throw new Error('Versão não encontrada em backend/app/main.py (FastAPI(version="..."))')

// Kit de telas @hl/ui: código-fonte do hl-core clonado ao lado deste projeto (..\..\hl-core\ui). O dedupe faz o kit
// usar o React/axios deste app (um só React na página).
const hlUi = fileURLToPath(new URL('../../hl-core/ui/src', import.meta.url))

export default defineConfig({
  plugins: [react()],
  define: { __APP_VERSION__: JSON.stringify(versao) },
  resolve: {
    alias: [
      { find: /^@hl\/ui\/estilo\.css$/, replacement: `${hlUi}/estilo.css` },
      { find: /^@hl\/ui$/, replacement: `${hlUi}/index.js` },
    ],
    dedupe: ['react', 'react-dom', 'react-router-dom', 'axios'],
  },
  server: {
    host: '0.0.0.0',
    port: 5175,
    fs: { allow: ['..', fileURLToPath(new URL('../../hl-core/ui', import.meta.url))] },
    // toda a API (inclusive o WebSocket /api/ws) está em /api
    proxy: {
      '/api':          { target: 'http://localhost:8003', ws: true, changeOrigin: true },
      '/docs':         { target: 'http://localhost:8003', changeOrigin: true },
      '/openapi.json': { target: 'http://localhost:8003', changeOrigin: true },
    },
  },
})
