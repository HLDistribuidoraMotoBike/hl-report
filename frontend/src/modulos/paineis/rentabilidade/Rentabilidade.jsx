import { useEffect, useMemo, useState } from 'react'
import { erroApi } from '@hl/ui'
import { executar } from '../../relatorios/api'
import {
  agregar, brl, classeMargem, classeMkp, dataBr, mapear, margem, mkpMedio, nomeCanal, num, ordenar, top5,
} from './dados'
import './rentabilidade.css'

// Painel de Rentabilidade (HL Report 0.3.0) — substitui as páginas RentabilidadeEcommerce.html e
// RentabilidadeConsolidado.html. Uma fonte (config.fonte, base HL_RENTABILIDADE desde a 0.4.0): visão E-commerce
// (canal = E-commerce) ou Consolidado (todas as empresas e canais).
const VISOES = [['ecommerce', 'E-commerce', 'E-commerce'], ['consolidado', 'Consolidado', '']]   // [chave, rótulo, canal]
const ABAS = [['visao', 'Visão geral'], ['graficos', 'Gráficos'], ['produtos', 'Produtos'], ['marcas', 'Marcas'], ['notas', 'Notas']]
const LIMITE_TABELA = 50
const hoje = () => new Date().toISOString().slice(0, 10)

function Badge({ valor, tipo }) {
  const cls = tipo === 'mkp' ? classeMkp(valor) : classeMargem(valor)
  return <span className={`rt-badge rt-${cls}`}>{tipo === 'mkp' ? `${num(valor, 3)}x` : `${num(valor, 1)}%`}</span>
}

function Cabecalho({ colunas, ordem, setOrdem }) {
  return (
    <thead>
      <tr>
        {colunas.map(([chave, rotulo, numerica]) => (
          <th key={rotulo} className={`${numerica ? 'rt-num' : ''}${chave ? ' rt-ord' : ''}`}
              onClick={() => chave && setOrdem(o => ({ coluna: chave, asc: o.coluna === chave ? !o.asc : false }))}>
            {rotulo}{chave && <span className="rt-seta">{ordem.coluna === chave ? (ordem.asc ? ' ↑' : ' ↓') : ' ↕'}</span>}
          </th>
        ))}
      </tr>
    </thead>
  )
}

function Barras({ titulo, dados }) {
  const max = Math.max(...dados.map(d => d.vlr), 1)
  return (
    <div className="card rt-grafico">
      <div className="rt-grafico-titulo">{titulo}</div>
      <div className="rt-legenda"><span className="rt-cor-vlr" /> Vlr anunciado <span className="rt-cor-rec" /> Receita líq. c/ crédito</div>
      {dados.map(d => (
        <div key={d.nome} className="rt-barra">
          <div className="rt-barra-rotulo">
            <span title={d.nome}>{d.nome}</span>
            <span className="rt-barra-vals"><b>{brl(d.vlr)}</b> · <i>{brl(d.receita)}</i></span>
          </div>
          <div className="rt-trilho"><div className="rt-fill-vlr" style={{ width: `${(d.vlr / max) * 100}%` }} /></div>
          <div className="rt-trilho rt-trilho-fino"><div className="rt-fill-rec" style={{ width: `${Math.max(0, (d.receita / max) * 100)}%` }} /></div>
        </div>
      ))}
    </div>
  )
}

// Painel lateral: todas as linhas de venda de um produto ou marca
function Detalhe({ grupo, tipo, onFechar }) {
  const [ordem, setOrdem] = useState('data')
  const [busca, setBusca] = useState('')
  useEffect(() => {
    const esc = e => { if (e.key === 'Escape') onFechar() }
    window.addEventListener('keydown', esc)
    return () => window.removeEventListener('keydown', esc)
  }, [onFechar])
  const termo = busca.toLowerCase()
  const linhas = grupo.linhas
    .filter(l => !termo || l.nf.toLowerCase().includes(termo) || l.loja.toLowerCase().includes(termo) || l.produto.toLowerCase().includes(termo))
    .sort((a, b) => (ordem === 'data' ? `${a.data}${a.hora}`.localeCompare(`${b.data}${b.hora}`) : b[ordem] - a[ordem]))
  const mg = margem(grupo), mk = mkpMedio(grupo)
  return (
    <div className="rt-fundo" onMouseDown={e => { if (e.target === e.currentTarget) onFechar() }}>
      <aside className="rt-gaveta">
        <div className="rt-gaveta-topo">
          <div>
            <div className="rt-sobre">{tipo === 'produto' ? 'Produto' : 'Marca'}</div>
            <h3>{tipo === 'produto' ? grupo.produto : grupo.chave || '(sem marca)'}</h3>
            <div className="text-muted">{tipo === 'produto' ? `${grupo.chave} · ${grupo.marca}` : `${grupo.freq} linha(s) de venda`}</div>
          </div>
          <button className="rt-x" onClick={onFechar} aria-label="Fechar">×</button>
        </div>
        <div className="rt-gaveta-kpis">
          <div><span>Vendas</span><b>{grupo.freq.toLocaleString('pt-BR')}</b></div>
          <div><span>Qtd.</span><b>{num(grupo.qtd, 0)}</b></div>
          <div><span>Vlr anunciado</span><b>{brl(grupo.vlr)}</b></div>
          <div><span>Receita líq.</span><b className="rt-verde">{brl(grupo.receita)}</b></div>
          <div><span>Impostos</span><b className="rt-vermelho">{brl(grupo.impostos)}</b></div>
          <div><span>Mkp médio</span><b><Badge valor={mk} tipo="mkp" /></b></div>
          <div><span>Margem</span><b><Badge valor={mg} /></b></div>
        </div>
        <div className="rt-gaveta-filtros">
          Ordenar:
          {[['data', 'Data'], ['vlr', 'Vlr anunciado'], ['receita', 'Receita'], ['mkp', 'Mkp']].map(([k, r]) => (
            <button key={k} className={`rt-chip${ordem === k ? ' rt-chip--on' : ''}`} onClick={() => setOrdem(k)}>{r}</button>
          ))}
          <input className="form-control rt-busca-peq" placeholder="Filtrar NF, loja ou produto…" value={busca} onChange={e => setBusca(e.target.value)} />
          <span className="text-muted">{linhas.length.toLocaleString('pt-BR')} registro(s)</span>
        </div>
        <div className="rt-gaveta-tabela">
          <table className="rt-tabela">
            <thead>
              <tr><th>NF</th><th>Loja</th><th>UF</th><th>Data</th><th>Hora</th>{tipo === 'marca' && <th>Produto</th>}
                <th className="rt-num">Qtd.</th><th className="rt-num">Vlr anunciado</th><th className="rt-num">Comissão</th>
                <th className="rt-num">Frete</th><th className="rt-num">Impostos</th><th className="rt-num">Receita líq.</th><th className="rt-num">Mkp</th></tr>
            </thead>
            <tbody>
              {linhas.map((l, i) => (
                <tr key={i}>
                  <td className="rt-mono">{l.nf}</td><td>{l.loja}</td><td>{l.uf}</td><td>{dataBr(l.data)}</td><td>{l.hora}</td>
                  {tipo === 'marca' && <td className="rt-corta" title={l.produto}>{l.produto}</td>}
                  <td className="rt-num">{num(l.qtd, 0)}</td><td className="rt-num">{brl(l.vlr)}</td><td className="rt-num">{brl(l.comissao)}</td>
                  <td className="rt-num">{brl(l.frete)}</td><td className="rt-num rt-vermelho">{brl(l.impostos)}</td>
                  <td className="rt-num rt-verde">{brl(l.receita)}</td><td className="rt-num"><Badge valor={l.mkp} tipo="mkp" /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </aside>
    </div>
  )
}

export default function Rentabilidade({ config }) {
  const [visao, setVisao] = useState('ecommerce')
  const [filtros, setFiltros] = useState({ data_ini: hoje(), data_fim: hoje(), marca: '' })
  const [estado, setEstado] = useState('inicial')   // inicial | carregando | erro | ok
  const [erro, setErro] = useState('')
  const [segundos, setSegundos] = useState(0)
  const [resultado, setResultado] = useState(null) // {visao, filtros, linhas}
  const [canal, setCanal] = useState('')
  const [aba, setAba] = useState('visao')
  const [busca, setBusca] = useState({ produtos: '', marcas: '', notas: '' })
  const [ordem, setOrdem] = useState({ produtos: { coluna: 'freq', asc: false }, marcas: { coluna: 'freq', asc: false }, notas: { coluna: 'data', asc: false } })
  const [todos, setTodos] = useState({ produtos: false, marcas: false })
  const [abertas, setAbertas] = useState(new Set())
  const [detalhe, setDetalhe] = useState(null)      // {grupo, tipo}

  useEffect(() => {
    if (estado !== 'carregando') return
    setSegundos(0)
    const t = setInterval(() => setSegundos(s => s + 1), 1000)
    return () => clearInterval(t)
  }, [estado])

  async function gerar() {
    if (!filtros.data_ini || !filtros.data_fim) { setEstado('erro'); setErro('Preencha as datas de início e fim.'); return }
    if (filtros.data_ini > filtros.data_fim) { setEstado('erro'); setErro('Data inicial maior que a final.'); return }
    setEstado('carregando'); setErro('')
    try {
      const { data: json } = await executar(config.fonte, { ...filtros, canal: VISOES.find(v => v[0] === visao)[2] })
      if (!json.ok) { setEstado('erro'); setErro(json.erro || 'Erro ao consultar.'); return }
      setResultado({ visao, filtros: { ...filtros }, linhas: json.data.map(mapear) })
      setCanal(''); setAbertas(new Set()); setDetalhe(null)
      setEstado('ok')
    } catch (e) {
      setEstado('erro'); setErro(erroApi(e, 'Erro de comunicação.'))
    }
  }

  const consolidado = resultado?.visao === 'consolidado'
  const canais = useMemo(() => (consolidado ? [...new Set(resultado.linhas.map(nomeCanal))].sort() : []), [resultado, consolidado])
  const ag = useMemo(() => {
    if (!resultado) return null
    return agregar(canal ? resultado.linhas.filter(l => nomeCanal(l) === canal) : resultado.linhas)
  }, [resultado, canal])

  const setBuscaDe = (k, v) => setBusca(b => ({ ...b, [k]: v }))
  const setOrdemDe = k => f => setOrdem(o => ({ ...o, [k]: typeof f === 'function' ? f(o[k]) : f }))
  const filtrar = (grupos, termo, campos) => {
    const q = termo.toLowerCase()
    return q ? grupos.filter(g => campos.some(c => String(g[c] ?? '').toLowerCase().includes(q))) : grupos
  }

  const periodo = resultado
    ? (resultado.filtros.data_ini === resultado.filtros.data_fim ? dataBr(resultado.filtros.data_ini)
      : `${dataBr(resultado.filtros.data_ini)} → ${dataBr(resultado.filtros.data_fim)}`)
    : ''

  return (
    <div className="rt-pagina">
      <div className="rl-topo">
        <h2 className="page-title">{config.titulo || 'Rentabilidade'}</h2>
        {resultado && <span className="text-muted">{VISOES.find(v => v[0] === resultado.visao)[1]} · {periodo}</span>}
        {estado === 'ok' && <span className="badge badge-success">{ag.linhas.toLocaleString('pt-BR')} linhas · {ag.notas.length.toLocaleString('pt-BR')} notas</span>}
      </div>

      <div className="card rt-filtros">
        <div className="rt-filtro">
          <label className="form-label">Visão</label>
          <div className="rt-segmento">
            {VISOES.map(([v, r]) => <button key={v} className={visao === v ? 'rt-seg--on' : ''} onClick={() => setVisao(v)}>{r}</button>)}
          </div>
        </div>
        <div className="rt-filtro">
          <label className="form-label">Data inicial</label>
          <input type="date" className="form-control" value={filtros.data_ini} onChange={e => setFiltros(f => ({ ...f, data_ini: e.target.value }))} />
        </div>
        <div className="rt-filtro">
          <label className="form-label">Data final</label>
          <input type="date" className="form-control" value={filtros.data_fim} onChange={e => setFiltros(f => ({ ...f, data_fim: e.target.value }))} />
        </div>
        <div className="rt-filtro">
          <label className="form-label">Marca (opcional)</label>
          <input className="form-control" placeholder="Ex.: PIRELLI" value={filtros.marca}
                 onChange={e => setFiltros(f => ({ ...f, marca: e.target.value }))} onKeyDown={e => { if (e.key === 'Enter') gerar() }} />
        </div>
        <button className="btn btn-primary" onClick={gerar} disabled={estado === 'carregando'}>
          {estado === 'carregando' ? `Consultando… ${segundos}s` : '▶ Gerar'}
        </button>
      </div>
      {estado !== 'ok' && (
        <div className="text-muted rt-nota">
          Base HL_RENTABILIDADE (mesmo critério do e-mail diário). {visao === 'consolidado' ? 'Consolidado: todas as empresas e canais.' : 'Só o canal E-commerce.'} ICMS Presumido entra como crédito.
        </div>
      )}

      {estado === 'inicial' && <div className="rl-estado">📊<div>Escolha a visão e o período e clique em <strong>Gerar</strong>.</div></div>}
      {estado === 'carregando' && <div className="rl-estado"><div className="spinner" /><div>Consultando o banco…</div></div>}
      {estado === 'erro' && <div className="alert alert-danger">⚠ {erro}</div>}
      {estado === 'ok' && ag.linhas === 0 && <div className="alert alert-info">Nenhuma venda no período.</div>}

      {estado === 'ok' && ag.linhas > 0 && (
        <>
          <div className="rt-abas">
            {ABAS.map(([k, r]) => <button key={k} className={`rt-aba${aba === k ? ' rt-aba--on' : ''}`} onClick={() => setAba(k)}>{r}</button>)}
            {consolidado && (
              <select className="form-control rt-canal" value={canal} onChange={e => setCanal(e.target.value)}>
                <option value="">Todos os canais</option>
                {canais.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            )}
          </div>

          {aba === 'visao' && (
            <>
              <div className="rt-kpis">
                {[
                  ['Valor anunciado', brl(ag.tot.vlr), 'destaque'],
                  ['Receita líquida c/ crédito', brl(ag.tot.receita), 'destaque verde'],
                  ['Crédito Pirelli', brl(ag.tot.credPirelli), 'azul'],
                  ['Crédito presumido (ICMS)', brl(ag.tot.presumido), 'verde'],
                  ['Valor de NF emitida', brl(ag.tot.vlrNF), ''],
                  ['Total de impostos', brl(ag.tot.impostos), 'vermelho'],
                  ['Receita bruta', brl(ag.tot.receitaBruta), ''],
                  ['Despesa operacional', brl(ag.tot.despOp), ''],
                  ['Margem', `${num(margem(ag.tot), 1)}%`, ''],
                ].map(([r, v, c]) => (
                  <div key={r} className={`card rt-kpi ${c}`}><div className="rt-kpi-rotulo">{r}</div><div className="rt-kpi-valor">{v}</div></div>
                ))}
              </div>

              <div className="adm-secao">Impostos</div>
              <div className="rt-impostos">
                {[['ICMS destacado', ag.tot.icms], ['DIFAL', ag.tot.difal], ['PIS', ag.tot.pis], ['COFINS', ag.tot.cofins], ['IPI', ag.tot.ipi],
                  ['ICMS transferência', ag.tot.transferencia]].map(([r, v]) => (
                  <div key={r} className="rt-imposto"><span>{r}</span><b>{brl(v)}</b></div>
                ))}
              </div>

              {consolidado && !canal && (
                <>
                  <div className="adm-secao">Por canal</div>
                  <div className="rt-cards">
                    {[...ag.canais].sort((a, b) => b.vlr - a.vlr).map(g => (
                      <button key={g.chave} className="card rt-card rt-card--clicavel" onClick={() => setCanal(g.chave)} title="Ver só este canal">
                        <div className="rt-card-nome">{g.chave}</div>
                        <div className="rt-card-vlr">{brl(g.vlr)}</div>
                        <div className="text-muted">Receita líq.: <b className="rt-verde">{brl(g.receita)}</b> · <Badge valor={margem(g)} /></div>
                      </button>
                    ))}
                  </div>
                </>
              )}

              <div className="adm-secao">{consolidado ? 'Por vendedor / loja' : 'Por loja'}</div>
              <div className="rt-cards">
                {[...ag.lojas].sort((a, b) => b.vlr - a.vlr).map(g => (
                  <div key={g.chave} className="card rt-card">
                    <div className="rt-card-nome">{g.chave || '(sem loja)'}</div>
                    <div className="rt-card-vlr">{brl(g.vlr)}</div>
                    <div className="text-muted">Receita líq.: <b className="rt-verde">{brl(g.receita)}</b> · <Badge valor={margem(g)} /></div>
                  </div>
                ))}
              </div>
            </>
          )}

          {aba === 'graficos' && (
            <div className="rt-graficos">
              {consolidado && !canal && <Barras titulo="Por canal" dados={top5(ag.canais)} />}
              <Barras titulo={consolidado ? 'Por vendedor / loja' : 'Por loja'} dados={top5(ag.lojas)} />
              <Barras titulo="Por UF" dados={top5(ag.ufs)} />
              <Barras titulo="Por marca" dados={top5(ag.marcas)} />
            </div>
          )}

          {aba === 'produtos' && (() => {
            const lista = ordenar(filtrar(ag.produtos, busca.produtos, ['chave', 'produto', 'marca']), ordem.produtos.coluna, ordem.produtos.asc)
            const vis = todos.produtos ? lista : lista.slice(0, LIMITE_TABELA)
            return (
              <div className="card rt-secao-tabela">
                <div className="rt-barra-tabela">
                  <input className="form-control rt-busca" placeholder="Buscar produto, código ou marca…" value={busca.produtos} onChange={e => setBuscaDe('produtos', e.target.value)} />
                  <span className="text-muted">{lista.length.toLocaleString('pt-BR')} produto(s)</span>
                </div>
                <div className="rt-tabela-wrap">
                  <table className="rt-tabela">
                    <Cabecalho ordem={ordem.produtos} setOrdem={setOrdemDe('produtos')} colunas={[
                      [null, '#'], [null, 'Código'], [null, 'Produto'], [null, 'Marca'], ['freq', 'Vendas', 1], ['qtd', 'Qtd.', 1],
                      ['vlr', 'Vlr anunciado', 1], ['receita', 'Receita líq.', 1], ['margem', 'Margem', 1], ['mkp', 'Mkp médio', 1], [null, '']]} />
                    <tbody>
                      {vis.map((g, i) => (
                        <tr key={g.chave}>
                          <td className="rt-rank">{i + 1}</td><td className="rt-mono">{g.chave}</td><td className="rt-corta" title={g.produto}>{g.produto}</td>
                          <td className="text-muted">{g.marca}</td><td className="rt-num">{g.freq.toLocaleString('pt-BR')}</td><td className="rt-num">{num(g.qtd, 0)}</td>
                          <td className="rt-num">{brl(g.vlr)}</td><td className="rt-num rt-verde">{brl(g.receita)}</td>
                          <td className="rt-num"><Badge valor={margem(g)} /></td><td className="rt-num"><Badge valor={mkpMedio(g)} tipo="mkp" /></td>
                          <td><button className="btn btn-outline btn-sm" onClick={() => setDetalhe({ grupo: g, tipo: 'produto' })} title="Ver as vendas">🔍</button></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {lista.length > LIMITE_TABELA && (
                  <button className="btn btn-outline btn-sm rt-mais" onClick={() => setTodos(t => ({ ...t, produtos: !t.produtos }))}>
                    {todos.produtos ? `Mostrar só os ${LIMITE_TABELA} primeiros` : `Mostrar todos (${lista.length.toLocaleString('pt-BR')})`}
                  </button>
                )}
              </div>
            )
          })()}

          {aba === 'marcas' && (() => {
            const lista = ordenar(filtrar(ag.marcas, busca.marcas, ['chave']), ordem.marcas.coluna, ordem.marcas.asc)
            const vis = todos.marcas ? lista : lista.slice(0, LIMITE_TABELA)
            return (
              <div className="card rt-secao-tabela">
                <div className="rt-barra-tabela">
                  <input className="form-control rt-busca" placeholder="Buscar marca…" value={busca.marcas} onChange={e => setBuscaDe('marcas', e.target.value)} />
                  <span className="text-muted">{lista.length.toLocaleString('pt-BR')} marca(s)</span>
                </div>
                <div className="rt-tabela-wrap">
                  <table className="rt-tabela">
                    <Cabecalho ordem={ordem.marcas} setOrdem={setOrdemDe('marcas')} colunas={[
                      [null, '#'], [null, 'Marca'], ['freq', 'Vendas', 1], ['qtd', 'Qtd.', 1], ['vlr', 'Vlr anunciado', 1],
                      ['receita', 'Receita líq.', 1], ['margem', 'Margem', 1], ['mkp', 'Mkp médio', 1], [null, '']]} />
                    <tbody>
                      {vis.map((g, i) => (
                        <tr key={g.chave}>
                          <td className="rt-rank">{i + 1}</td><td><b>{g.chave || '(sem marca)'}</b></td>
                          <td className="rt-num">{g.freq.toLocaleString('pt-BR')}</td><td className="rt-num">{num(g.qtd, 0)}</td>
                          <td className="rt-num">{brl(g.vlr)}</td><td className="rt-num rt-verde">{brl(g.receita)}</td>
                          <td className="rt-num"><Badge valor={margem(g)} /></td><td className="rt-num"><Badge valor={mkpMedio(g)} tipo="mkp" /></td>
                          <td><button className="btn btn-outline btn-sm" onClick={() => setDetalhe({ grupo: g, tipo: 'marca' })} title="Ver as vendas">🔍</button></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {lista.length > LIMITE_TABELA && (
                  <button className="btn btn-outline btn-sm rt-mais" onClick={() => setTodos(t => ({ ...t, marcas: !t.marcas }))}>
                    {todos.marcas ? `Mostrar só as ${LIMITE_TABELA} primeiras` : `Mostrar todas (${lista.length.toLocaleString('pt-BR')})`}
                  </button>
                )}
              </div>
            )
          })()}

          {aba === 'notas' && (() => {
            const lista = ordenar(filtrar(ag.notas, busca.notas, ['nf', 'loja', 'uf', 'canal']), ordem.notas.coluna, ordem.notas.asc)
            return (
              <div className="card rt-secao-tabela">
                <div className="rt-barra-tabela">
                  <input className="form-control rt-busca" placeholder="Buscar NF, loja ou UF…" value={busca.notas}
                         onChange={e => { setBuscaDe('notas', e.target.value); setAbertas(new Set()) }} />
                  <span className="text-muted">{lista.length.toLocaleString('pt-BR')} nota(s)</span>
                </div>
                <div className="rt-tabela-wrap rt-alta">
                  <table className="rt-tabela">
                    <Cabecalho ordem={ordem.notas} setOrdem={setOrdemDe('notas')} colunas={[
                      [null, ''], [null, 'NF'], [null, consolidado ? 'Vendedor / loja' : 'Loja'], ...(consolidado ? [[null, 'Canal']] : []), [null, 'UF'],
                      ['data', 'Data'], ['vlr', 'Vlr anunciado', 1], ['impostos', 'Impostos', 1], ['receita', 'Receita líq.', 1], ['margem', 'Margem', 1]]} />
                    <tbody>
                      {lista.map(g => {
                        const aberta = abertas.has(g.chave)
                        return [
                          <tr key={g.chave} className={aberta ? 'rt-aberta' : ''}>
                            <td><button className="btn btn-outline btn-sm" onClick={() => setAbertas(a => { const s = new Set(a); s.has(g.chave) ? s.delete(g.chave) : s.add(g.chave); return s })}>
                              {aberta ? '▲' : '▼'} {g.freq}
                            </button></td>
                            <td className="rt-mono">{g.nf}</td><td>{g.loja}</td>{consolidado && <td>{g.canal}</td>}<td>{g.uf}</td>
                            <td>{dataBr(g.data)} <span className="text-muted">{g.hora}</span></td>
                            <td className="rt-num">{brl(g.vlr)}</td><td className="rt-num rt-vermelho">{brl(g.impostos)}</td>
                            <td className="rt-num rt-verde">{brl(g.receita)}</td><td className="rt-num"><Badge valor={margem(g)} /></td>
                          </tr>,
                          aberta && (
                            <tr key={`${g.chave}-itens`} className="rt-itens">
                              <td colSpan={consolidado ? 10 : 9}>
                                <table className="rt-tabela rt-sub">
                                  <thead><tr><th>Código</th><th>Produto</th><th>Marca</th><th className="rt-num">Qtd.</th><th className="rt-num">Vlr anunciado</th><th className="rt-num">Receita líq.</th><th className="rt-num">Mkp</th></tr></thead>
                                  <tbody>
                                    {g.linhas.map((l, i) => (
                                      <tr key={i}><td className="rt-mono">{l.itemCode}</td><td>{l.produto}</td><td className="text-muted">{l.marca}</td>
                                        <td className="rt-num">{num(l.qtd, 0)}</td><td className="rt-num">{brl(l.vlr)}</td>
                                        <td className="rt-num rt-verde">{brl(l.receita)}</td><td className="rt-num"><Badge valor={l.mkp} tipo="mkp" /></td></tr>
                                    ))}
                                  </tbody>
                                </table>
                              </td>
                            </tr>
                          ),
                        ]
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
            )
          })()}
        </>
      )}

      {detalhe && <Detalhe grupo={detalhe.grupo} tipo={detalhe.tipo} onFechar={() => setDetalhe(null)} />}
    </div>
  )
}
