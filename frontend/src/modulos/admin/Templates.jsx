import { useCallback, useEffect, useState } from 'react'
import { erroApi } from '@hl/ui'
import { excluirTemplate, lerTemplate, listarTemplates, salvarTemplate } from './api'
import { Aviso, BotaoConfirmar, EditorCodigo, Modal } from './comum'

// Configurações → Templates: páginas dos relatórios do tipo indicador (relatorios/templates) e modelos dos e-mails
// agendados (relatorios/email/templates). HTML com Jinja.
const TIPOS = [
  ['relatorio', 'Páginas de indicador', 'Variáveis: nome, rel_id, config ({{ config | tojson }}). Dados via fetch("/api/executar/Pasta/Nome?...").'],
  ['email', 'Modelos de e-mail', 'Contexto do processador do e-mail, ou o padrão: titulo, periodo, data_geracao, subtitulo_tabela, kpis, colunas, dados.'],
]

export default function Templates() {
  const [tipo, setTipo] = useState('relatorio')
  const [lista, setLista] = useState([])
  const [sel, setSel] = useState(null)
  const [html, setHtml] = useState('')
  const [original, setOriginal] = useState('')
  const [pendente, setPendente] = useState(null)
  const [msg, setMsg] = useState(null)
  const [novo, setNovo] = useState(false)

  const carregar = useCallback(t => listarTemplates(t).then(r => setLista(r.data)).catch(e => setMsg({ tipo: 'erro', texto: erroApi(e) })), [])
  useEffect(() => { carregar(tipo) }, [tipo, carregar])

  const sujo = sel && html !== original

  async function abrir(nome, forcar = false) {
    if (sujo && !forcar) { setPendente({ nome }); return }
    setPendente(null)
    try {
      const { data } = await lerTemplate(tipo, nome)
      setSel(data.nome); setHtml(data.html); setOriginal(data.html)
    } catch (e) {
      setMsg({ tipo: 'erro', texto: erroApi(e) })
    }
  }

  function trocarTipo(t, forcar = false) {
    if (t === tipo) return
    if (sujo && !forcar) { setPendente({ tipo: t }); return }
    setPendente(null); setTipo(t); setSel(null); setHtml(''); setOriginal('')
  }

  async function salvar() {
    if (!sujo) return
    try {
      await salvarTemplate(tipo, { nome: sel, html, novo: false })
      setOriginal(html)
      setMsg({ tipo: 'ok', texto: `${sel} salvo.` })
    } catch (e) {
      setMsg({ tipo: 'erro', texto: erroApi(e) })
    }
  }

  async function excluir() {
    try {
      await excluirTemplate(tipo, sel)
      setMsg({ tipo: 'ok', texto: `${sel} excluído.` })
      setSel(null); setHtml(''); setOriginal('')
      carregar(tipo)
    } catch (e) {
      setMsg({ tipo: 'erro', texto: erroApi(e) })
    }
  }

  const [, rotulo, ajuda] = TIPOS.find(t => t[0] === tipo)

  return (
    <div className="adm-pagina">
      <div className="adm-topo">
        <h2 className="page-title">Templates</h2>
        <button className="btn btn-primary btn-sm" onClick={() => setNovo(true)}>+ Template</button>
      </div>
      <Aviso msg={msg} onFechar={() => setMsg(null)} />
      <div className="adm-abas">
        {TIPOS.map(([t, l]) => <button key={t} className={`adm-aba${tipo === t ? ' adm-aba--ativa' : ''}`} onClick={() => trocarTipo(t)}>{l}</button>)}
      </div>
      {pendente && (
        <div className="alert alert-warning adm-aviso">
          <span>Há alterações não salvas em {sel}. Descartar?</span>
          <span className="adm-acoes">
            <button className="btn btn-danger btn-sm" onClick={() => (pendente.tipo ? trocarTipo(pendente.tipo, true) : abrir(pendente.nome, true))}>Descartar</button>
            <button className="btn btn-outline btn-sm" onClick={() => setPendente(null)}>Continuar editando</button>
          </span>
        </div>
      )}
      <div className="adm-split">
        <div className="card adm-lista">
          {lista.length === 0 && <div className="adm-vazio-lista">Nenhum template.</div>}
          {lista.map(n => (
            <button key={n} className={`adm-item${sel === n ? ' adm-item--ativo' : ''}`} style={{ paddingLeft: '.9rem' }} onClick={() => abrir(n)}>{n}</button>
          ))}
        </div>
        <div className="card" style={{ minWidth: 0 }}>
          {!sel && <div className="text-muted" style={{ padding: '2rem', textAlign: 'center' }}>Escolha um template ({rotulo.toLowerCase()}).</div>}
          {sel && (
            <>
              <div className="adm-editor-topo">
                <span className="adm-id">{sel}</span>
                {sujo && <span className="adm-sujo">● não salvo</span>}
                <BotaoConfirmar confirmar="Excluir mesmo?" onClick={excluir}>Excluir</BotaoConfirmar>
                <button className="btn btn-primary btn-sm" onClick={salvar} disabled={!sujo}>Salvar</button>
              </div>
              <EditorCodigo valor={html} onChange={setHtml} onSalvar={salvar} linhas={30} />
              <div className="adm-ajuda">{ajuda} Ctrl+S salva.</div>
            </>
          )}
        </div>
      </div>
      {novo && <NovoTemplate tipo={tipo} rotulo={rotulo} onFechar={() => setNovo(false)}
                             onCriado={async nome => { setNovo(false); await carregar(tipo); abrir(nome, true) }} />}
    </div>
  )
}

function NovoTemplate({ tipo, rotulo, onFechar, onCriado }) {
  const [nome, setNome] = useState('')
  const [erro, setErro] = useState('')
  async function criar() {
    const base = tipo === 'relatorio'
      ? '<!DOCTYPE html>\n<html lang="pt-BR">\n<head>\n<meta charset="UTF-8">\n<title>{{ config.titulo }}</title>\n</head>\n<body>\n<h1>{{ config.titulo }}</h1>\n<script>\nconst CFG = {{ config | tojson }};\nconst REL_ID = {{ rel_id | tojson }};\n</script>\n</body>\n</html>\n'
      : '<html><body>\n<h2>{{ titulo }}</h2>\n<p>{{ periodo }}</p>\n</body></html>\n'
    try {
      const { data } = await salvarTemplate(tipo, { nome, html: base, novo: true })
      onCriado(data.nome)
    } catch (e) {
      setErro(erroApi(e))
    }
  }
  return (
    <Modal titulo={`Novo template — ${rotulo.toLowerCase()}`} onFechar={onFechar}>
      <label className="form-label">Nome do arquivo</label>
      <input className="form-control" autoFocus value={nome} placeholder="MeuRelatorio.html" onChange={e => setNome(e.target.value)} onKeyDown={e => { if (e.key === 'Enter') criar() }} />
      {erro && <div className="alert alert-danger" style={{ marginTop: '.8rem' }}>{erro}</div>}
      <div className="adm-acoes" style={{ marginTop: '1rem', justifyContent: 'flex-end' }}>
        <button className="btn btn-outline" onClick={onFechar}>Cancelar</button>
        <button className="btn btn-primary" onClick={criar} disabled={!nome.trim()}>Criar</button>
      </div>
    </Modal>
  )
}
