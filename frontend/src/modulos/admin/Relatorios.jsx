import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { erroApi } from '@hl/ui'
import { useRecarregarCatalogo } from '../../catalogo'
import { rotaDoRelatorio } from '../relatorios/api'
import { criarPasta, excluirPasta, excluirSql, getArvore, lerSql, listarTemplates, parametrosDoSql, salvarSql, testarSql } from './api'
import { Aviso, BotaoConfirmar, EditorCodigo, Modal, TabelaResultado } from './comum'
import { TIPOS_FILTRO, paraConfig, paraFormulario } from './configForm'

// Configurações → Relatórios: pastas e relatórios (SQL + configuração), com teste da consulta antes de salvar.
// Grava na pasta de relatórios do servidor — em produção, trazer depois para o git (docs/PUBLICACAO.md).

const instantaneo = e => (e ? JSON.stringify([e.sql, e.form]) : '')

export default function Relatorios() {
  const recarregarCatalogo = useRecarregarCatalogo()
  const [arvore, setArvore] = useState([])
  const [abertas, setAbertas] = useState(new Set())
  const [sel, setSel] = useState(null)            // id selecionado
  const [ed, setEd] = useState(null)              // {id, auxiliar, sql, form}
  const [original, setOriginal] = useState('')
  const [pendente, setPendente] = useState(null)  // id para abrir depois de confirmar o descarte
  const [aba, setAba] = useState('sql')
  const [msg, setMsg] = useState(null)
  const [salvando, setSalvando] = useState(false)
  const [templates, setTemplates] = useState([])
  const [teste, setTeste] = useState({ valores: {}, resultado: null, erro: '', rodando: false })
  const [modal, setModal] = useState(null)        // 'pasta' | 'relatorio'

  const carregarArvore = useCallback(() => getArvore().then(r => setArvore(r.data)).catch(e => setMsg({ tipo: 'erro', texto: erroApi(e) })), [])
  useEffect(() => { carregarArvore() }, [carregarArvore])
  useEffect(() => { listarTemplates('relatorio').then(r => setTemplates(r.data)).catch(() => {}) }, [])

  const sujo = ed && instantaneo(ed) !== original
  const itemSel = useMemo(() => arvore.flatMap(p => p.itens).find(i => i.id === sel), [arvore, sel])

  async function abrir(id, forcar = false) {
    if (sujo && !forcar) { setPendente(id); return }
    setPendente(null); setMsg(null)
    try {
      const { data } = await lerSql(id)
      const item = arvore.flatMap(p => p.itens).find(i => i.id === id)
      const novo = { id: data.id, auxiliar: !!item?.auxiliar, sql: data.sql, form: paraFormulario(data.config, id.split('/').pop()) }
      setSel(id); setEd(novo); setOriginal(instantaneo(novo)); setAba('sql')
      setTeste({ valores: {}, resultado: null, erro: '', rodando: false })
      setAbertas(a => new Set(a).add(id.split('/')[0]))
    } catch (e) {
      setMsg({ tipo: 'erro', texto: erroApi(e) })
    }
  }

  async function salvar() {
    if (!ed || salvando) return
    let config
    try {
      config = ed.auxiliar ? null : paraConfig(ed.form)
    } catch (e) {
      setMsg({ tipo: 'erro', texto: e.message }); setAba('config'); return
    }
    setSalvando(true)
    try {
      await salvarSql({ id: ed.id, sql: ed.sql, config, novo: false })
      setOriginal(instantaneo(ed))
      setMsg({ tipo: 'ok', texto: `${ed.id} salvo.` })
      carregarArvore(); recarregarCatalogo()
    } catch (e) {
      setMsg({ tipo: 'erro', texto: erroApi(e) })
    } finally {
      setSalvando(false)
    }
  }

  async function excluir() {
    try {
      await excluirSql(ed.id)
      setMsg({ tipo: 'ok', texto: `${ed.id} excluído.` })
      setSel(null); setEd(null); setOriginal('')
      carregarArvore(); recarregarCatalogo()
    } catch (e) {
      setMsg({ tipo: 'erro', texto: erroApi(e) })
    }
  }

  async function apagarPasta(nome) {
    try {
      await excluirPasta(nome)
      setMsg({ tipo: 'ok', texto: `Pasta ${nome} excluída.` })
      carregarArvore(); recarregarCatalogo()
    } catch (e) {
      setMsg({ tipo: 'erro', texto: erroApi(e) })
    }
  }

  async function rodarTeste() {
    setTeste(t => ({ ...t, rodando: true, erro: '', resultado: null }))
    try {
      const { data } = await testarSql(ed.sql, teste.valores, ed.form.schema)
      setTeste(t => ({ ...t, rodando: false, resultado: data }))
    } catch (e) {
      setTeste(t => ({ ...t, rodando: false, erro: erroApi(e) }))
    }
  }

  const setForm = mudanca => setEd(e => ({ ...e, form: { ...e.form, ...mudanca } }))
  const setFiltro = (i, mudanca) => setForm({ filtros: ed.form.filtros.map((f, k) => (k === i ? { ...f, ...mudanca } : f)) })
  const params = ed ? parametrosDoSql(ed.sql) : []
  const pastaVazia = p => p.itens.length === 0

  return (
    <div className="adm-pagina">
      <div className="adm-topo">
        <h2 className="page-title">Relatórios</h2>
        <button className="btn btn-outline btn-sm" onClick={() => setModal('pasta')}>+ Pasta</button>
        <button className="btn btn-primary btn-sm" onClick={() => setModal('relatorio')}>+ Relatório</button>
      </div>
      <Aviso msg={msg} onFechar={() => setMsg(null)} />

      <div className="adm-split">
        <div className="card adm-lista">
          {arvore.map(p => (
            <div key={p.pasta}>
              <div className="adm-pasta" onClick={() => setAbertas(a => { const n = new Set(a); n.has(p.pasta) ? n.delete(p.pasta) : n.add(p.pasta); return n })}>
                <span>{abertas.has(p.pasta) ? '▾' : '▸'}</span> {p.pasta}
                <span className="adm-qtd">{p.itens.length}</span>
              </div>
              {abertas.has(p.pasta) && (
                <>
                  {p.itens.map(i => (
                    <button key={i.id} className={`adm-item${sel === i.id ? ' adm-item--ativo' : ''}${i.auxiliar ? ' adm-item--aux' : ''}`}
                            onClick={() => abrir(i.id)} title={i.id}>
                      {i.auxiliar ? '↳ ' : i.tipo === 'indicador' ? '📊 ' : '📋 '}{i.auxiliar ? i.nome : i.titulo}
                    </button>
                  ))}
                  {pastaVazia(p) && (
                    <div className="adm-vazio-lista">
                      Pasta vazia. <BotaoConfirmar className="btn btn-outline btn-sm" confirmar="Excluir pasta?" onClick={() => apagarPasta(p.pasta)}>Excluir pasta</BotaoConfirmar>
                    </div>
                  )}
                </>
              )}
            </div>
          ))}
        </div>

        <div className="card" style={{ minWidth: 0 }}>
          {pendente && (
            <div className="alert alert-warning adm-aviso">
              <span>Há alterações não salvas em {ed?.id}. Descartar?</span>
              <span className="adm-acoes">
                <button className="btn btn-danger btn-sm" onClick={() => abrir(pendente, true)}>Descartar</button>
                <button className="btn btn-outline btn-sm" onClick={() => setPendente(null)}>Continuar editando</button>
              </span>
            </div>
          )}
          {!ed && <div className="text-muted" style={{ padding: '2rem', textAlign: 'center' }}>Escolha um relatório na lista ou crie um novo.</div>}
          {ed && (
            <>
              <div className="adm-editor-topo">
                <span className="adm-id">{ed.id}</span>
                {sujo && <span className="adm-sujo">● não salvo</span>}
                {!ed.auxiliar && itemSel && <Link className="btn btn-outline btn-sm" to={rotaDoRelatorio(ed.id)}>Abrir relatório</Link>}
                <BotaoConfirmar confirmar="Excluir mesmo?" onClick={excluir}>Excluir</BotaoConfirmar>
                <button className="btn btn-primary btn-sm" onClick={salvar} disabled={!sujo || salvando}>{salvando ? 'Salvando...' : 'Salvar'}</button>
              </div>
              <div className="adm-abas">
                <button className={`adm-aba${aba === 'sql' ? ' adm-aba--ativa' : ''}`} onClick={() => setAba('sql')}>SQL</button>
                {!ed.auxiliar && <button className={`adm-aba${aba === 'config' ? ' adm-aba--ativa' : ''}`} onClick={() => setAba('config')}>Configuração</button>}
                <button className={`adm-aba${aba === 'teste' ? ' adm-aba--ativa' : ''}`} onClick={() => setAba('teste')}>Testar</button>
              </div>

              {aba === 'sql' && (
                <>
                  <EditorCodigo valor={ed.sql} onChange={sql => setEd(e => ({ ...e, sql }))} onSalvar={salvar} linhas={26} />
                  <div className="adm-ajuda">
                    Filtros como <code>:nome</code> (viram parâmetros; vazio = ''). Linhas começando com <code>--</code> são ignoradas. Ctrl+S salva.
                    {params.length > 0 && <> Filtros usados: <strong>{params.join(', ')}</strong>.</>}
                  </div>
                </>
              )}

              {aba === 'config' && !ed.auxiliar && (
                <>
                  <label className="adm-chave-liga" style={{ marginBottom: '.8rem' }}>
                    <input type="checkbox" checked={ed.form.usaConfig} onChange={e => setForm({ usaConfig: e.target.checked })} />
                    Configuração própria {!ed.form.usaConfig && <span className="text-muted">— sem ela: lista com os filtros Data Inicial, Data Final, Marca e Loja</span>}
                  </label>
                  {ed.form.usaConfig && (
                    <>
                      <div className="adm-grade">
                        <div>
                          <label className="form-label">Título (menu e tela)</label>
                          <input className="form-control" value={ed.form.titulo} onChange={e => setForm({ titulo: e.target.value })} />
                        </div>
                        <div>
                          <label className="form-label">Tipo</label>
                          <select className="form-control" value={ed.form.tipo} onChange={e => setForm({ tipo: e.target.value })}>
                            <option value="lista">Lista (tabela padrão)</option>
                            <option value="indicador">Indicador (página própria)</option>
                          </select>
                        </div>
                        {ed.form.tipo === 'indicador' && (
                          <div>
                            <label className="form-label">Página (template)</label>
                            <select className="form-control" value={ed.form.template} onChange={e => setForm({ template: e.target.value })}>
                              <option value="">{`${ed.id.split('/').pop()}.html (padrão)`}</option>
                              {templates.map(t => <option key={t} value={t}>{t}</option>)}
                            </select>
                          </div>
                        )}
                        <div>
                          <label className="form-label">Schema (opcional)</label>
                          <input className="form-control" value={ed.form.schema} placeholder="padrão da conexão" onChange={e => setForm({ schema: e.target.value })} />
                          <div className="adm-ajuda">Ex.: SBO_MATRIZ — só para este relatório.</div>
                        </div>
                      </div>

                      <div className="adm-secao">Filtros da tela</div>
                      <table className="adm-filtros">
                        <thead><tr><th>id (:nome no SQL)</th><th>Rótulo</th><th>Tipo</th><th>Dica / opções da lista</th><th /></tr></thead>
                        <tbody>
                          {ed.form.filtros.map((f, i) => (
                            <tr key={i}>
                              <td><input className="form-control" value={f.id} onChange={e => setFiltro(i, { id: e.target.value })} /></td>
                              <td><input className="form-control" value={f.label} onChange={e => setFiltro(i, { label: e.target.value })} /></td>
                              <td>
                                <select className="form-control" value={f.tipo} onChange={e => setFiltro(i, { tipo: e.target.value })}>
                                  {TIPOS_FILTRO.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                                </select>
                              </td>
                              <td>
                                {f.tipo === 'select'
                                  ? <textarea className="form-control" rows={3} value={f.opcoes} placeholder={'valor | rótulo (uma por linha)'} onChange={e => setFiltro(i, { opcoes: e.target.value })} />
                                  : <input className="form-control" value={f.placeholder} placeholder="texto de dica (opcional)" onChange={e => setFiltro(i, { placeholder: e.target.value })} />}
                              </td>
                              <td>
                                <button className="btn btn-outline btn-sm" onClick={() => setForm({ filtros: ed.form.filtros.filter((_, k) => k !== i) })}>×</button>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                      <div className="adm-acoes" style={{ marginTop: '.5rem' }}>
                        <button className="btn btn-outline btn-sm" onClick={() => setForm({ filtros: [...ed.form.filtros, { id: '', label: '', tipo: 'text', placeholder: '', opcoes: '', extra: {} }] })}>+ Filtro</button>
                        {ed.form.tipo !== 'indicador' && params.filter(p => !ed.form.filtros.some(f => f.id === p)).map(p => (
                          <button key={p} className="btn btn-outline btn-sm" title="O SQL usa este filtro e ele não está na tela"
                                  onClick={() => setForm({ filtros: [...ed.form.filtros, { id: p, label: p, tipo: p.startsWith('data') ? 'date' : 'text', placeholder: '', opcoes: '', extra: {} }] })}>
                            + {p}
                          </button>
                        ))}
                      </div>

                      <div className="adm-secao">Avançado (JSON)</div>
                      <EditorCodigo valor={ed.form.avancado} onChange={v => setForm({ avancado: v })} onSalvar={salvar} linhas={8} />
                      <div className="adm-ajuda">
                        Demais chaves do config: <code>modo: "pivot"</code> (+ colunas_fixas, colunas_mes_label, colunas_mes_qtd),
                        <code> colunas_congeladas</code>, <code>agrupamento</code> e as dos indicadores. Formato em relatorios/README.md.
                      </div>
                    </>
                  )}
                </>
              )}

              {aba === 'teste' && (
                <>
                  <div className="adm-ajuda" style={{ marginBottom: '.6rem' }}>
                    Roda o SQL do editor (mesmo sem salvar) no HANA{ed.form.schema ? ` (schema ${ed.form.schema})` : ''} e mostra até 200 linhas.
                  </div>
                  {params.length > 0 && (
                    <div className="adm-grade">
                      {params.map(p => (
                        <div key={p}>
                          <label className="form-label">:{p}</label>
                          <input className="form-control" value={teste.valores[p] || ''} placeholder={p.startsWith('data') ? 'AAAA-MM-DD' : ''}
                                 onChange={e => setTeste(t => ({ ...t, valores: { ...t.valores, [p]: e.target.value } }))}
                                 onKeyDown={e => { if (e.key === 'Enter') rodarTeste() }} />
                        </div>
                      ))}
                    </div>
                  )}
                  <div className="adm-acoes" style={{ marginBottom: '.8rem' }}>
                    <button className="btn btn-primary btn-sm" onClick={rodarTeste} disabled={teste.rodando}>{teste.rodando ? 'Executando...' : '▶ Executar'}</button>
                    {teste.resultado && <span className="text-muted">{teste.resultado.data.length} linha(s){teste.resultado.cortado ? ' — mostrando só as primeiras 200' : ''}</span>}
                  </div>
                  {teste.erro && <div className="alert alert-danger">⚠ {teste.erro}</div>}
                  {teste.resultado && <TabelaResultado colunas={teste.resultado.colunas} linhas={teste.resultado.data} />}
                </>
              )}
            </>
          )}
        </div>
      </div>

      {modal === 'pasta' && <NovaPasta onFechar={() => setModal(null)} onCriada={nome => { setModal(null); setMsg({ tipo: 'ok', texto: `Pasta ${nome} criada — libere-a para os grupos em Admin → Grupos.` }); setAbertas(a => new Set(a).add(nome)); carregarArvore(); recarregarCatalogo() }} />}
      {modal === 'relatorio' && <NovoRelatorio pastas={arvore.map(p => p.pasta)} onFechar={() => setModal(null)}
                                               onCriado={async id => { setModal(null); await carregarArvore(); recarregarCatalogo(); abrir(id, true) }} />}
    </div>
  )
}

function NovaPasta({ onFechar, onCriada }) {
  const [nome, setNome] = useState('')
  const [erro, setErro] = useState('')
  async function criar() {
    try {
      const { data } = await criarPasta(nome)
      onCriada(data.nome)
    } catch (e) {
      setErro(erroApi(e))
    }
  }
  return (
    <Modal titulo="Nova pasta" onFechar={onFechar}>
      <label className="form-label">Nome</label>
      <input className="form-control" autoFocus value={nome} onChange={e => setNome(e.target.value)} onKeyDown={e => { if (e.key === 'Enter') criar() }} />
      <div className="adm-ajuda">A pasta é o que se libera para um grupo (Admin → Grupos).</div>
      {erro && <div className="alert alert-danger" style={{ marginTop: '.8rem' }}>{erro}</div>}
      <div className="adm-acoes" style={{ marginTop: '1rem', justifyContent: 'flex-end' }}>
        <button className="btn btn-outline" onClick={onFechar}>Cancelar</button>
        <button className="btn btn-primary" onClick={criar} disabled={!nome.trim()}>Criar</button>
      </div>
    </Modal>
  )
}

function NovoRelatorio({ pastas, onFechar, onCriado }) {
  const [pasta, setPasta] = useState(pastas.find(p => p !== 'Geral') || '')
  const [nome, setNome] = useState('')
  const [sub, setSub] = useState('')
  const [erro, setErro] = useState('')
  async function criar() {
    const subpasta = sub.trim() ? (sub.trim().startsWith('_') ? sub.trim() : `_${sub.trim()}`) : ''
    const id = [pasta, subpasta, nome.trim()].filter(Boolean).join('/')
    try {
      await salvarSql({ id, sql: '-- Escreva a consulta (filtros como :data_ini)\nSELECT 1 FROM DUMMY', config: null, novo: true })
      onCriado(id)
    } catch (e) {
      setErro(erroApi(e))
    }
  }
  return (
    <Modal titulo="Novo relatório" onFechar={onFechar}>
      <div className="adm-grade" style={{ gridTemplateColumns: '1fr' }}>
        <div>
          <label className="form-label">Pasta</label>
          <select className="form-control" value={pasta} onChange={e => setPasta(e.target.value)}>
            {pastas.map(p => <option key={p} value={p}>{p}</option>)}
          </select>
        </div>
        <div>
          <label className="form-label">Nome do arquivo</label>
          <input className="form-control" autoFocus value={nome} onChange={e => setNome(e.target.value)} onKeyDown={e => { if (e.key === 'Enter') criar() }} />
          <div className="adm-ajuda">Vira o endereço e o título padrão (o título pode mudar na configuração).</div>
        </div>
        <div>
          <label className="form-label">Subpasta (opcional)</label>
          <input className="form-control" value={sub} placeholder="ex.: _dre" onChange={e => setSub(e.target.value)} />
          <div className="adm-ajuda">Só para consulta auxiliar de um indicador — não aparece no menu.</div>
        </div>
      </div>
      {erro && <div className="alert alert-danger">{erro}</div>}
      <div className="adm-acoes" style={{ marginTop: '1rem', justifyContent: 'flex-end' }}>
        <button className="btn btn-outline" onClick={onFechar}>Cancelar</button>
        <button className="btn btn-primary" onClick={criar} disabled={!pasta || !nome.trim()}>Criar</button>
      </div>
    </Modal>
  )
}
