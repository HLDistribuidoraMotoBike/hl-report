import React from 'react'
import ReactDOM from 'react-dom/client'
import '@hl/ui/estilo.css'
import App from './App.jsx'
import { registrarClienteDasPaginas } from './modulos/relatorios/api'

// as páginas de indicador (iframe) usam o cliente desta tela nas chamadas /api
registrarClienteDasPaginas()

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
