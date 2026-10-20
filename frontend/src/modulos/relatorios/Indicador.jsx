import { useEffect, useState } from 'react'
import { erroApi } from '@hl/ui'
import { abrirPagina } from './api'

// Relatório do tipo "indicador" (DRE, Rentabilidade, Simulador...): a página própria dele (relatorios/templates/)
// dentro do layout do app, num iframe do mesmo endereço. Login e chamadas: ver backend app/modulos/relatorios/paginas.py.
export default function Indicador({ relId }) {
  const [url, setUrl] = useState(null)
  const [erro, setErro] = useState('')

  useEffect(() => {
    let vivo = true
    setUrl(null); setErro('')
    abrirPagina(relId)
      .then(r => { if (vivo) setUrl(r.data.url) })
      .catch(e => { if (vivo) setErro(erroApi(e, 'Erro ao abrir o relatório.')) })
    return () => { vivo = false }
  }, [relId])

  if (erro) return <div className="alert alert-danger">{erro}</div>
  if (!url) return <div className="loading-center"><div className="spinner" /></div>
  return <iframe className="rl-indicador" src={url} title={relId} />
}
