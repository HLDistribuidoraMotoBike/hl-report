import { useEffect, useState } from 'react'
import { useLocation } from 'react-router-dom'
import { erroApi } from '@hl/ui'
import { getConfig } from './api'
import Indicador from './Indicador'
import Lista from './Lista'
import './relatorios.css'

// Tela de um relatório (/r/<Pasta>/<Nome>): lê a configuração e abre a lista ou a página do indicador.
export default function Relatorio() {
  const { pathname } = useLocation()
  const relId = pathname.replace(/^\/r\//, '').split('/').map(decodeURIComponent).join('/')
  const [config, setConfig] = useState(null)
  const [erro, setErro] = useState('')

  useEffect(() => {
    let vivo = true
    setConfig(null); setErro('')
    getConfig(relId)
      .then(r => { if (vivo) setConfig(r.data) })
      .catch(e => { if (vivo) setErro(erroApi(e, 'Erro ao carregar o relatório.')) })
    return () => { vivo = false }
  }, [relId])

  if (erro) return <div className="page-wrapper"><div className="alert alert-danger">{erro}</div></div>
  if (!config) return <div className="loading-center"><div className="spinner" /></div>
  if (config.tipo === 'indicador') return <Indicador relId={relId} />
  return <Lista relId={relId} config={config} />
}
