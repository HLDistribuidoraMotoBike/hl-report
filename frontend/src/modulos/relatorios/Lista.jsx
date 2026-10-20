import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { erroApi } from '@hl/ui'
import { executar } from './api'
import {
  POR_PAGINA, achatar, agregar, baixarCsv, baixarExcel, colunasExibidas, colunasVisiveis, compararSimples,
  compararValores, ehDecimalTexto, formatNum, formatarData, lerAgrupamento, montarArvore, nomeDoMes, numero,
  rotulosDeMes, todosOsCaminhos,
} from './tabela'

// Relatório do tipo "lista" (o ListTemplate do Report antigo): filtros do config, tabela com busca, filtro por coluna,
// ordenação, paginação, colunas congeladas, modo pivot (meses em colunas) e agrupamento com totais.

function valorInicial(f) {
  if (f.tipo !== 'date') return ''
  const hoje = new Date()
  if (f.id === 'data_ini') return new Date(hoje.getFullYear(), hoje.getMonth(), 1).toISOString().slice(0, 10)
  if (f.id === 'data_fim') return hoje.toISOString().slice(0, 10)
  return ''
}

function Filtro({ def, valor, onChange, onEnter }) {
  const comum = {
    id: `f_${def.id}`, className: 'form-control', value: valor,
    onChange: e => onChange(e.target.value), onKeyDown: e => { if (e.key === 'Enter') onEnter() },
  }
  let campo
  if (def.tipo === 'date') campo = <input type="date" {...comum} />
  else if (def.tipo === 'number') campo = <input type="number" placeholder={def.placeholder || ''} {...comum} />
  else if (def.tipo === 'select') {
    const opcoes = def.opcoes || []
    campo = (
      <select {...comum}>
        {!opcoes.some(op => (op.value ?? op) === '') && <option value="">Todos</option>}
        {opcoes.map(op => <option key={op.value ?? op} value={op.value ?? op}>{op.label ?? op}</option>)}
      </select>
    )
  } else campo = <input type="text" placeholder={def.placeholder || 'Todos'} {...comum} />
  return (
    <div className="rl-filtro">
      <label className="form-label" htmlFor={`f_${def.id}`}>{def.label}</label>
      {campo}
    </div>
  )
}

function Celula({ v, className = '', style }) {
  if (v === null || v === undefined) return <td className={`rl-vazio ${className}`} style={style}>—</td>
  if (typeof v === 'number' || ehDecimalTexto(v)) return <td className={`rl-num ${className}`} style={style}>{formatNum(v)}</td>
  return <td className={className} style={style}>{formatarData(v)}</td>
}

function Paginacao({ total, pagina, setPagina }) {
  const paginas = Math.ceil(total / POR_PAGINA)
  const ini = Math.min((pagina - 1) * POR_PAGINA + 1, total), fim = Math.min(pagina * POR_PAGINA, total)
  const vis = new Set([1, paginas])
  for (let p = Math.max(1, pagina - 2); p <= Math.min(paginas, pagina + 2); p++) vis.add(p)
  const lista = [...vis].filter(p => p >= 1).sort((a, b) => a - b)
  const botoes = []
  let ant = 0
  lista.forEach(p => {
    if (ant && p - ant > 1) botoes.push(<button key={`r${p}`} className="rl-pag" disabled>…</button>)
    botoes.push(<button key={p} className={`rl-pag${p === pagina ? ' rl-pag--ativa' : ''}`} onClick={() => setPagina(p)}>{p}</button>)
    ant = p
  })
  return (
    <div className="rl-paginacao">
      <span className="text-muted">{total > 0 ? `Exibindo ${ini}–${fim} de ${total.toLocaleString('pt-BR')}` : 'Sem resultados'}</span>
      <div className="rl-pag-btns">
        <button className="rl-pag" disabled={pagina === 1} onClick={() => setPagina(pagina - 1)}>‹</button>
        {botoes}
        <button className="rl-pag" disabled={pagina >= paginas} onClick={() => setPagina(pagina + 1)}>›</button>
      </div>
    </div>
  )
}

export default function Lista({ relId, config }) {
  const defs = config.filtros || []
  const modo = config.modo || 'lista'
  const pivot = modo === 'pivot'
  const agrup = useMemo(() => lerAgrupamento(config), [config])
  const colsFixas = config.colunas_fixas || []
  const colsMesLabel = config.colunas_mes_label || []
  const colsMesQtd = config.colunas_mes_qtd || []
  const congeladas = agrup ? 0 : (config.colunas_congeladas || 0)
  const titulo = config.titulo || relId.split('/').pop()

  const [filtros, setFiltros] = useState(() => Object.fromEntries(defs.map(f => [f.id, valorInicial(f)])))
  const [estado, setEstado] = useState('inicial')   // inicial | carregando | erro | ok
  const [erro, setErro] = useState('')
  const [dados, setDados] = useState([])
  const [colunas, setColunas] = useState([])
  const [meses, setMeses] = useState([])
  const [busca, setBusca] = useState('')
  const [filtrosCol, setFiltrosCol] = useState({})
  const [ordem, setOrdem] = useState({ col: null, asc: true })
  const [pagina, setPagina] = useState(1)
  const [abertos, setAbertos] = useState(new Set())

  // Relatório trocado pelo menu: volta ao começo
  useEffect(() => {
    setFiltros(Object.fromEntries(defs.map(f => [f.id, valorInicial(f)])))
    limparResultado()
  }, [relId])  // eslint-disable-line react-hooks/exhaustive-deps

  function limparResultado() {
    setEstado('inicial'); setErro(''); setDados([]); setColunas([]); setMeses([])
    setBusca(''); setFiltrosCol({}); setOrdem({ col: null, asc: true }); setPagina(1); setAbertos(new Set())
  }

  async function rodar() {
    setEstado('carregando'); setErro('')
    try {
      const { data: json } = await executar(relId, filtros)
      if (!json.ok) { setEstado('erro'); setErro(json.erro || 'Erro ao executar.'); return }
      setDados(json.data); setColunas(json.colunas)
      setMeses(pivot ? rotulosDeMes(json, colsMesLabel) : [])
      setFiltrosCol({}); setPagina(1); setOrdem({ col: null, asc: true })
      if (agrup?.expandido) {
        setAbertos(todosOsCaminhos(montarArvore(json.data, agrup, null, true)))
      } else setAbertos(new Set())
      setEstado('ok')
    } catch (e) {
      setEstado('erro'); setErro(erroApi(e, 'Erro de comunicação.'))
    }
  }

  // ── Dados derivados ──
  const filtrados = useMemo(() => {
    const termo = busca.toLowerCase()
    const colsBusca = pivot ? colsFixas : colunas
    let ls = dados.filter(row => {
      for (const [col, val] of Object.entries(filtrosCol)) {
        if (!val) continue
        const alvo = col === '__grupo__'
          ? agrup.niveis.map(n => `${row[n.coluna] ?? ''} ${row[n.rotulo] ?? ''}`).join(' ')
          : row[col]
        if (!String(alvo ?? '').toLowerCase().includes(val.toLowerCase())) return false
      }
      return !termo || colsBusca.map(c => String(row[c] ?? '')).join(' ').toLowerCase().includes(termo)
    })
    if (ordem.col) {
      ls = [...ls].sort((a, b) => agrup
        ? (a[ordem.col] == null ? 1 : b[ordem.col] == null ? -1 : compararValores(a[ordem.col], b[ordem.col]) * (ordem.asc ? 1 : -1))
        : compararSimples(a[ordem.col], b[ordem.col], ordem.asc))
    }
    return ls
  }, [dados, colunas, busca, filtrosCol, ordem, pivot, agrup])  // eslint-disable-line react-hooks/exhaustive-deps

  const arvore = useMemo(() => agrup ? montarArvore(filtrados, agrup, ordem.col, ordem.asc) : [], [filtrados, agrup, ordem])
  const visiveis = useMemo(() => agrup ? achatar(arvore, abertos) : [], [arvore, abertos, agrup])
  const colsAgrup = agrup ? colunasVisiveis(colunas, agrup, visiveis, filtrosCol) : []
  const linhasPaginadas = agrup ? visiveis : filtrados
  const totalPaginas = Math.max(1, Math.ceil(linhasPaginadas.length / POR_PAGINA))
  const paginaAtual = Math.min(pagina, totalPaginas)
  const inicio = (paginaAtual - 1) * POR_PAGINA
  const naPagina = linhasPaginadas.slice(inicio, inicio + POR_PAGINA)

  // ── Colunas congeladas e cabeçalho do pivot: medem a largura/altura real depois de desenhar ──
  const wrapRef = useRef(null)
  const [offsets, setOffsets] = useState([])
  const [alturaGrupo, setAlturaGrupo] = useState(0)
  useLayoutEffect(() => {
    const wrap = wrapRef.current
    if (!wrap) return
    const g = wrap.querySelector('tr.rl-tr-grupo')
    const h = g ? g.offsetHeight : 0
    if (h !== alturaGrupo) setAlturaGrupo(h)
    if (!congeladas) return
    const ths = [...wrap.querySelectorAll('thead tr:last-child th')].slice(0, congeladas)
    let left = 0
    const novos = ths.map(th => { const o = left; left += th.offsetWidth; return o })
    if (novos.join() !== offsets.join()) setOffsets(novos)
  })

  const congelada = i => i < congeladas
    ? { className: `rl-congelada${i === congeladas - 1 ? ' rl-congelada-ultima' : ''}`, style: { left: offsets[i] ?? 0 } }
    : { className: '', style: undefined }

  function ordenar(col) {
    setOrdem(o => (o.col === col ? { col, asc: !o.asc } : { col, asc: true }))
    setPagina(1)
  }

  function filtrarColuna(col, val) {
    setFiltrosCol(f => ({ ...f, [col]: val }))
    setPagina(1)
  }

  function alternarGrupo(no) {
    setAbertos(a => {
      const n = new Set(a)
      if (n.has(no.caminho)) [...n].forEach(c => { if (c === no.caminho || c.startsWith(no.caminho + '\u0001')) n.delete(c) })
      else n.add(no.caminho)
      return n
    })
  }

  // funções (não componentes): um componente criado dentro do render remontaria o campo e tiraria o foco a cada letra
  function tituloColuna(col, rotulo, alinhar) {
    const ativo = ordem.col === col
    return (
      <div className={`rl-th-titulo${ativo ? ' rl-th-titulo--ativo' : ''}`} style={alinhar ? { justifyContent: 'flex-end' } : undefined}
           onClick={() => ordenar(col)}>
        {rotulo ?? col} <span className="rl-sort">{ativo ? (ordem.asc ? '↑' : '↓') : '↕'}</span>
      </div>
    )
  }

  const filtroColuna = col => (
    <input className="rl-th-filtro" placeholder="▼ filtrar" value={filtrosCol[col] || ''}
           onChange={e => filtrarColuna(col, e.target.value)} onClick={e => e.stopPropagation()} />
  )

  // ── Exportação (mesmo conteúdo do Report antigo) ──
  async function exportarExcel() {
    if (pivot) {
      const linhas = filtrados.map(row => {
        const obj = {}
        colsFixas.forEach(c => { obj[c] = row[c] ?? '' })
        meses.forEach((m, i) => { obj[m] = Number(row[colsMesQtd[i]]) || 0 })
        return obj
      })
      const tot = {}
      colsFixas.forEach((c, i) => { tot[c] = i === 0 ? 'TOTAL' : '' })
      meses.forEach((m, i) => { tot[m] = filtrados.reduce((s, r) => s + (Number(r[colsMesQtd[i]]) || 0), 0) })
      await baixarExcel(titulo || 'Pivot', [[titulo || 'Pivot', [...linhas, tot]]])
    } else if (agrup) {
      const resumo = []
      ;(function percorrer(nos) {
        nos.forEach(no => {
          const obj = { 'Nível': no.nivel + 1 }
          agrup.niveis.forEach((n, i) => {
            obj[n.rotulo] = i <= no.nivel ? (no.chaves[i].rotulo ?? '') : ''
            if (n.coluna !== n.rotulo) obj[n.coluna] = i <= no.nivel ? (no.chaves[i].chave ?? '') : ''
          })
          obj.Linhas = no.linhas.length
          Object.keys(agrup.agregacoes).forEach(c => { obj[c] = no.agg[c] ?? '' })
          resumo.push(obj)
          percorrer(no.filhos)
        })
      })(arvore)
      const analitico = filtrados.map(row => Object.fromEntries(colunas.map(c => [c, ehDecimalTexto(row[c]) ? numero(row[c]) : (row[c] ?? '')])))
      await baixarExcel(titulo, [['Resumo', resumo], ['Analítico', analitico]])
    } else {
      await baixarExcel(titulo, [['Relatório', filtrados.map(row => Object.fromEntries(colunas.map(c => [c, row[c] ?? ''])))]])
    }
  }

  function exportarCsv() {
    if (pivot) {
      const cab = [...colsFixas, ...meses]
      baixarCsv(titulo || 'Pivot', cab, filtrados.map(row => cab.map(h => {
        const i = meses.indexOf(h)
        return i >= 0 ? (Number(row[colsMesQtd[i]]) || 0) : (row[h] ?? '')
      })))
    } else {
      baixarCsv(titulo, colunas, filtrados.map(r => colunas.map(c => r[c] ?? '')))
    }
  }

  // ── Partes da tabela ──
  function cabecalho() {
    if (pivot) {
      return (
        <thead>
          <tr className="rl-tr-grupo">
            {congeladas > 0
              ? <>
                  <th colSpan={congeladas} className="rl-congelada" style={{ left: 0 }}>Informações do Produto</th>
                  {colsFixas.length - congeladas > 0 && <th colSpan={colsFixas.length - congeladas} />}
                </>
              : <th colSpan={colsFixas.length}>Informações do Produto</th>}
            <th colSpan={meses.length} className="rl-grupo-mes">Vendas por Mês (qtd)</th>
          </tr>
          <tr>
            {colsFixas.map((c, i) => {
              const cg = congelada(i)
              return (
                <th key={c} className={cg.className} style={{ ...cg.style, top: alturaGrupo }}>
                  {tituloColuna(c)}{filtroColuna(c)}
                </th>
              )
            })}
            {meses.map((m, i) => (
              <th key={m + i} className="rl-th-mes" style={{ top: alturaGrupo }}>
                {tituloColuna(colsMesQtd[i], nomeDoMes(m), true)}
              </th>
            ))}
          </tr>
        </thead>
      )
    }
    if (agrup) {
      return (
        <thead>
          <tr>
            <th>
              <div className="rl-th-titulo" style={{ cursor: 'default' }}>{agrup.titulo || agrup.niveis.map(n => n.rotulo).join(' › ')}</div>
              {filtroColuna('__grupo__')}
            </th>
            {colsAgrup.map(c => <th key={c}>{tituloColuna(c)}{filtroColuna(c)}</th>)}
          </tr>
        </thead>
      )
    }
    return (
      <thead>
        <tr>
          {colunas.map((c, i) => {
            const cg = congelada(i)
            return <th key={c} className={cg.className} style={cg.style}>{tituloColuna(c)}{filtroColuna(c)}</th>
          })}
        </tr>
      </thead>
    )
  }

  function corpo() {
    const nCols = pivot ? colsFixas.length + meses.length : agrup ? colsAgrup.length + 1 : colunas.length
    if (naPagina.length === 0) {
      return <tbody><tr><td colSpan={nCols} className="rl-vazio" style={{ padding: 40 }}>Nenhum registro encontrado.</td></tr></tbody>
    }
    if (pivot) {
      const max = colsMesQtd.map(c => Math.max(...naPagina.map(r => Number(r[c]) || 0)))
      return (
        <tbody>
          {naPagina.map((row, k) => (
            <tr key={k}>
              {colsFixas.map((c, i) => { const cg = congelada(i); return <Celula key={c} v={row[c]} className={cg.className} style={cg.style} /> })}
              {colsMesQtd.map((c, i) => {
                const v = Number(row[c]) || 0
                const pct = max[i] > 0 ? v / max[i] : 0
                const style = v > 0 ? { background: `rgba(0,184,148,${(0.1 + pct * 0.35).toFixed(2)})`, fontWeight: pct > 0.6 ? 700 : 400 } : undefined
                return <td key={c} className={`rl-num rl-mes${v === 0 ? ' rl-vazio' : ''}`} style={style}>{v === 0 ? '—' : formatNum(v)}</td>
              })}
            </tr>
          ))}
        </tbody>
      )
    }
    if (agrup) {
      return (
        <tbody>
          {naPagina.map((item, k) => {
            if (item.tipo === 'linha') {
              return <tr key={k}><td />{colsAgrup.map(c => <Celula key={c} v={item.row[c]} />)}</tr>
            }
            const no = item.no
            return (
              <tr key={no.caminho} className={`rl-tr-agrup rl-n${Math.min(no.nivel, 1)}`} onClick={() => alternarGrupo(no)}>
                <td className="rl-grp" style={{ paddingLeft: 12 + no.nivel * 22 }}>
                  <span className="rl-grp-toggle">{abertos.has(no.caminho) ? '−' : '+'}</span>{no.rotulo}
                  {no.sub && <span className="rl-grp-sub">{no.sub}</span>}
                  <span className="rl-grp-sub">({no.linhas.length.toLocaleString('pt-BR')})</span>
                </td>
                {colsAgrup.map(c => c in no.agg ? <Celula key={c} v={no.agg[c]} /> : <td key={c} />)}
              </tr>
            )
          })}
        </tbody>
      )
    }
    return (
      <tbody>
        {naPagina.map((row, k) => (
          <tr key={k}>{colunas.map((c, i) => { const cg = congelada(i); return <Celula key={c} v={row[c]} className={cg.className} style={cg.style} /> })}</tr>
        ))}
      </tbody>
    )
  }

  function rodape() {
    if (pivot) {
      return (
        <tfoot>
          <tr className="rl-tr-total">
            <td colSpan={colsFixas.length} className={congeladas ? 'rl-congelada' : ''} style={{ left: 0, textAlign: 'right' }}>TOTAL DO PERÍODO</td>
            {colsMesQtd.map(c => <td key={c} className="rl-num rl-mes">{formatNum(filtrados.reduce((s, r) => s + (Number(r[c]) || 0), 0))}</td>)}
          </tr>
        </tfoot>
      )
    }
    if (agrup && agrup.total_geral !== false && filtrados.length) {
      const agg = agregar(filtrados, agrup.agregacoes)
      return (
        <tfoot>
          <tr className="rl-tr-total">
            <td className="rl-grp">TOTAL GERAL<span className="rl-grp-sub">({filtrados.length.toLocaleString('pt-BR')})</span></td>
            {colsAgrup.map(c => c in agg ? <Celula key={c} v={agg[c]} /> : <td key={c} />)}
          </tr>
        </tfoot>
      )
    }
    return null
  }

  const badge = pivot ? ['⚡ Pivot', 'rl-badge--pivot'] : agrup ? ['▤ Agrupado', 'rl-badge--agrupado'] : ['📋 Lista', '']

  return (
    <div className="rl-pagina">
      <div className="rl-topo">
        <h2 className="page-title">{titulo}</h2>
        <span className={`rl-badge ${badge[1]}`}>{badge[0]}</span>
        {estado === 'ok' && <span className="badge badge-success">{dados.length.toLocaleString('pt-BR')} registros</span>}
        {estado === 'carregando' && <span className="badge badge-info">Carregando...</span>}
        {estado === 'erro' && <span className="badge badge-danger">Erro</span>}
      </div>

      <div className="card rl-filtros">
        {defs.map(f => (
          <Filtro key={f.id} def={f} valor={filtros[f.id] ?? ''} onEnter={rodar}
                  onChange={v => setFiltros(fs => ({ ...fs, [f.id]: v }))} />
        ))}
        <div className="rl-filtros-acoes">
          <button className="btn btn-primary" onClick={rodar} disabled={estado === 'carregando'}>▶ Executar</button>
          <button className="btn btn-outline" onClick={() => { setFiltros(Object.fromEntries(defs.map(f => [f.id, '']))); limparResultado() }}>✕ Limpar</button>
        </div>
      </div>

      {estado === 'inicial' && <div className="rl-estado">🔍<div>Configure os filtros e clique em <strong>Executar</strong></div></div>}
      {estado === 'carregando' && <div className="rl-estado"><div className="spinner" /><div>Executando consulta...</div></div>}
      {estado === 'erro' && <div className="alert alert-danger">⚠ {erro}</div>}

      {estado === 'ok' && (
        <>
          <div className="rl-barra">
            <input className="form-control rl-busca" placeholder="🔍 Buscar em todos os campos..." value={busca}
                   onChange={e => { setBusca(e.target.value); setPagina(1) }} />
            <span className="text-muted"><strong>{filtrados.length.toLocaleString('pt-BR')}</strong> de {dados.length.toLocaleString('pt-BR')} registros</span>
            <div className="rl-barra-acoes">
              {agrup && <>
                <button className="btn btn-outline btn-sm" onClick={() => setAbertos(todosOsCaminhos(arvore))}>＋ Expandir tudo</button>
                <button className="btn btn-outline btn-sm" onClick={() => { setAbertos(new Set()); setPagina(1) }}>− Recolher tudo</button>
              </>}
              <button className="btn btn-outline btn-sm" onClick={exportarExcel}>↓ Excel</button>
              <button className="btn btn-outline btn-sm" onClick={exportarCsv}>↓ CSV</button>
            </div>
          </div>
          <div className="rl-tabela-wrap" ref={wrapRef}>
            <table className="rl-tabela">
              {cabecalho()}
              {corpo()}
              {rodape()}
            </table>
          </div>
          <Paginacao total={linhasPaginadas.length} pagina={paginaAtual} setPagina={p => { setPagina(p); wrapRef.current?.scrollTo(0, 0) }} />
        </>
      )}
    </div>
  )
}
