import { useEffect, useMemo, useState } from 'react'
import { erroApi } from '@hl/ui'
import { executar as executarApi } from '../../relatorios/api'
import { calcular, fmtBRL, fmtPct, mesesDoPeriodo, montarDados, somaMeses, variacao } from './dados'
import Detalhe from './Detalhe'
import { exportarExcel } from './excel'
import './dre.css'

// DRE Diretoria (painel React do HL Report 0.6.0) — substitui o DRE.html. Modelo financeiro do SAP (OFRC/FRC1) com
// os saldos do período; empresas combináveis; clique numa conta abre parceiros e lançamentos.

// executar das fontes: devolve as linhas ou lança o erro do servidor
async function executar(relId, filtros) {
  const { data } = await executarApi(relId, filtros)
  if (!data.ok) throw new Error(data.erro || 'Erro na consulta.')
  return data.data
}

const ym = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
function periodoPadrao() {
  const fim = new Date(); fim.setDate(1); fim.setMonth(fim.getMonth() - 1)
  return { ini: ym(new Date(fim.getFullYear(), 0, 1)), fim: ym(fim) }
}

function Segmento({ opcoes, valor, onChange }) {
  return (
    <div className="dre-seg">
      {opcoes.map(([v, r]) => <button key={v} className={valor === v ? 'on' : ''} onClick={() => onChange(v)}>{r}</button>)}
    </div>
  )
}

function Marca({ texto, termo }) {
  if (!termo) return texto
  const i = texto.toLowerCase().indexOf(termo.toLowerCase())
  if (i < 0) return texto
  return <>{texto.slice(0, i)}<mark>{texto.slice(i, i + termo.length)}</mark>{texto.slice(i + termo.length)}</>
}

export default function Dre({ config }) {
  const cfg = config
  const [periodo, setPeriodo] = useState(periodoPadrao)
  const [semEncerramento, setSemEncerramento] = useState(true)
  const [estado, setEstado] = useState('inicial')   // inicial | carregando | erro | ok
  const [erro, setErro] = useState('')
  const [D, setD] = useState(null)
  const [meses, setMeses] = useState([])            // índices dos meses marcados
  const [grupos, setGrupos] = useState(new Set(['base']))
  const [colunas, setColunas] = useState('mensal')  // mensal | total
  const [modo, setModo] = useState('rs')            // rs | pct
  const [unidade, setUnidade] = useState('inteiro') // inteiro | milhar
  const [busca, setBusca] = useState('')
  const [termo, setTermo] = useState('')
  const [comVariacao, setComVariacao] = useState(true)
  const [ocultarZeradas, setOcultarZeradas] = useState(true)
  const [recolhidos, setRecolhidos] = useState(new Set())
  const [detalhe, setDetalhe] = useState(null)      // {codigo, nome, meses}

  useEffect(() => {
    const t = setTimeout(() => { setTermo(busca.trim()); if (busca.trim()) setRecolhidos(new Set()) }, 150)
    return () => clearTimeout(t)
  }, [busca])

  async function gerar() {
    const { ini, fim } = periodo
    if (!ini || !fim) { setEstado('erro'); setErro('Informe o mês inicial e o final.'); return }
    if (fim < ini) { setEstado('erro'); setErro('O mês final é anterior ao inicial.'); return }
    const max = cfg.max_meses || 24
    if (mesesDoPeriodo(ini, fim).length > max) { setEstado('erro'); setErro(`Período máximo de ${max} meses.`); return }
    setEstado('carregando'); setErro('')
    try {
      const dados = await montarDados(executar, cfg, ini, fim, !semEncerramento)
      setD(dados); setMeses(dados.meses.map((_, i) => i)); setRecolhidos(new Set()); setDetalhe(null)
      setEstado('ok')
    } catch (e) {
      setEstado('erro'); setErro(erroApi(e, e.message))
    }
  }

  const arvore = useMemo(() => (D ? calcular(D, grupos) : null), [D, grupos])
  const linhaChave = k => arvore.nosLinha.get(D.linhasChave[k])
  const receitaDe = idx => somaMeses(linhaChave('receita_liquida').monthly, idx)
  const pctReceita = (v, idx) => { const b = receitaDe(idx); return Math.abs(b) < 0.001 ? 0 : (v / b) * 100 }
  const fmtVal = v => (modo === 'pct' ? fmtPct(v) : fmtBRL(v, unidade))
  const valorMes = (no, i) => (modo === 'pct' ? pctReceita(no.monthly[i], [i]) : no.monthly[i])
  const valorTotal = no => { const v = somaMeses(no.monthly, meses); return modo === 'pct' ? pctReceita(v, meses) : v }
  const casa = no => !termo || no.name.toLowerCase().includes(termo.toLowerCase()) || no.fullName.toLowerCase().includes(termo.toLowerCase())
    || (no.children || []).some(casa)
  const zerada = no => meses.every(i => Math.abs(no.monthly[i]) < 0.005)
  const visivel = no => casa(no) && !(ocultarZeradas && no.type !== 'result' && zerada(no))
  const nomesEmpresas = D ? D.grupos.filter(g => grupos.has(g.chave)).map(g => g.rotulo) : []
  const rotuloEmpresas = D ? `${nomesEmpresas.length === D.grupos.length ? 'Todas as empresas' : 'Empresas'}: ${nomesEmpresas.join(' + ')}` : ''

  function alternarGrupo(chave, on) {
    if (!on && grupos.size === 1) return   // ao menos uma empresa
    setGrupos(g => { const n = new Set(g); on ? n.add(chave) : n.delete(chave); return n })
  }
  function alternarMes(i) {
    setMeses(m => (m.includes(i) ? (m.length === 1 ? m : m.filter(x => x !== i)) : [...m, i].sort((a, b) => a - b)))
  }
  function expandir(tudo) {
    if (tudo) setRecolhidos(new Set())
    else setRecolhidos(new Set([...arvore.nos.values()].filter(n => n.children?.length).map(n => n.key)))
  }

  function linhas(nos, nivel) {
    const out = []
    for (const no of nos) {
      if (!visivel(no)) continue
      const grupo = !!no.children?.length
      const recolhido = grupo && recolhidos.has(no.key)
      const tipo = no.type === 'result' ? 'dre-resultado' : grupo ? 'dre-grupo' : 'dre-conta'
      const clicavel = (idx, v) => (no.type === 'line' && Math.abs(v) > 0.004 ? () => setDetalhe({ codigo: no.code, nome: no.name, meses: idx }) : null)
      const celula = (chave, v, idx, bruto, extra = '') => {
        const abrir = clicavel(idx, bruto)
        return <td key={chave} className={`${v < 0 ? 'dre-neg' : ''} ${extra} ${abrir ? 'dre-clicavel' : ''}`} onClick={abrir || undefined}
                   title={abrir ? 'Ver fornecedores e lançamentos' : undefined}>{fmtVal(v)}</td>
      }
      const tds = []
      if (colunas === 'mensal') {
        meses.forEach(i => tds.push(celula(i, valorMes(no, i), [i], no.monthly[i])))
        if (meses.length > 1) tds.push(celula('t', valorTotal(no), meses, somaMeses(no.monthly, meses), 'dre-col-total'))
        if (meses.length > 1 && comVariacao) {
          const v = variacao(no, meses)
          const seta = v?.seta === 'up' ? '▲' : v?.seta === 'down' ? '▼' : '•'
          const rot = v == null ? '—' : v.pct === null ? 'novo' : `${Math.round(Math.abs(v.pct)) > 9999 ? '9999+' : Math.round(Math.abs(v.pct))}%`
          tds.push(<td key="v" className={`dre-col-var ${v?.cor === 'up' ? 'dre-pos' : v?.cor === 'down' ? 'dre-neg' : 'dre-mudo'}`}>{v == null ? '—' : `${seta} ${rot}`}</td>)
        }
      } else {
        tds.push(celula('t', valorTotal(no), meses, somaMeses(no.monthly, meses)))
      }
      out.push(
        <tr key={no.key} className={tipo} title={no.fullName}>
          <td className="dre-col-conta" style={{ paddingLeft: 12 + nivel * 18 }}>
            {grupo
              ? <button className="dre-alterna" onClick={() => setRecolhidos(r => { const n = new Set(r); n.has(no.key) ? n.delete(no.key) : n.add(no.key); return n })}>
                  <span className={`dre-chev${recolhido ? ' fechado' : ''}`}>▾</span><Marca texto={no.name} termo={termo} />
                </button>
              : <Marca texto={no.name} termo={termo} />}
          </td>
          {tds}
        </tr>,
      )
      if (grupo && !recolhido) out.push(...linhas(no.children, nivel + 1))
    }
    return out
  }

  const kpis = arvore && (() => {
    const s = k => somaMeses(linhaChave(k).monthly, meses)
    const rec = s('receita_liquida')
    const m = v => (rec ? `margem ${(v / rec * 100).toLocaleString('pt-BR', { maximumFractionDigits: 1 })}%` : '')
    return [
      ['Receita líquida', rec, `${meses.length} de ${D.meses.length} meses`],
      ['Lucro bruto', s('lucro_bruto'), m(s('lucro_bruto'))],
      ['Lucro operacional', s('lucro_operacional'), m(s('lucro_operacional'))],
      ['Resultado financeiro', s('resultado_financeiro'), 'receitas − despesas financeiras'],
      ['Lucro líquido', s('lucro_liquido'), m(s('lucro_liquido'))],
    ]
  })()

  const corpo = arvore ? linhas(arvore.raiz, 0) : []
  const nCols = 1 + (colunas === 'mensal' ? meses.length + (meses.length > 1 ? 1 : 0) + (meses.length > 1 && comVariacao ? 1 : 0) : 1)

  return (
    <div className="dre-pagina">
      <div className="dre-topo">
        <div>
          <h2 className="page-title">Demonstração do Resultado</h2>
          <p className="page-subtitle">
            {D ? <>{D.periodo} · {rotuloEmpresas} · regime de competência · valores em R${unidade === 'milhar' ? ' mil' : ''}</>
              : 'Relatório gerencial da Diretoria — modelo financeiro do SAP.'}
          </p>
        </div>
      </div>

      <div className="card dre-gerar no-print">
        <div className="dre-filtro">
          <label className="form-label">Mês inicial</label>
          <input type="month" className="form-control" value={periodo.ini} onChange={e => setPeriodo(p => ({ ...p, ini: e.target.value }))} />
        </div>
        <div className="dre-filtro">
          <label className="form-label">Mês final</label>
          <input type="month" className="form-control" value={periodo.fim} onChange={e => setPeriodo(p => ({ ...p, fim: e.target.value }))} />
        </div>
        <label className="dre-check" title="Lançamentos de encerramento do exercício (tipo -3 no SAP) zeram as contas de resultado no fim do ano">
          <input type="checkbox" checked={semEncerramento} onChange={e => setSemEncerramento(e.target.checked)} />
          Excluir encerramento do exercício
        </label>
        <button className="btn btn-primary" onClick={gerar} disabled={estado === 'carregando'}>{estado === 'carregando' ? 'Consultando…' : '▶ Gerar'}</button>
        {D && D.incluirEncerramento !== !semEncerramento && <span className="dre-aviso">Opção de encerramento mudou — clique em Gerar.</span>}
      </div>

      {estado === 'inicial' && <div className="rl-estado">📊<div>Informe o período e clique em <strong>Gerar</strong>.</div></div>}
      {estado === 'carregando' && !D && <div className="rl-estado"><div className="spinner" /><div>Consultando o banco…</div></div>}
      {estado === 'erro' && <div className="alert alert-danger">⚠ {erro}</div>}

      {D && arvore && (
        <>
          <div className="dre-kpis">
            {kpis.map(([r, v, s]) => (
              <div key={r} className="card dre-kpi">
                <div className="dre-kpi-rotulo">{r}</div>
                <div className={`dre-kpi-valor ${v < 0 ? 'dre-neg' : ''}`}>{fmtBRL(v, unidade)}</div>
                <div className="dre-kpi-sub">{s}</div>
              </div>
            ))}
          </div>

          <div className="card dre-barra no-print">
            <div className="dre-bloco">
              <span className="dre-bloco-tit">Meses</span>
              <div className="dre-pills">
                {D.meses.map((m, i) => <button key={m} className={`dre-pill${meses.includes(i) ? ' on' : ''}`} onClick={() => alternarMes(i)}>{m}</button>)}
              </div>
            </div>
            <div className="dre-bloco">
              <span className="dre-bloco-tit">Empresas</span>
              <div className="dre-pills">
                {D.grupos.map(g => (
                  <label key={g.chave} className={`dre-empresa${grupos.has(g.chave) ? ' on' : ''}`} title={g.detalhe}>
                    <input type="checkbox" checked={grupos.has(g.chave)} onChange={e => alternarGrupo(g.chave, e.target.checked)} />
                    {g.rotulo} <small>{g.detalhe}</small>
                  </label>
                ))}
              </div>
            </div>
            <div className="dre-bloco"><span className="dre-bloco-tit">Colunas</span>
              <Segmento valor={colunas} onChange={setColunas} opcoes={[['mensal', 'Por mês'], ['total', 'Total do período']]} /></div>
            <div className="dre-bloco"><span className="dre-bloco-tit">Visualizar como</span>
              <Segmento valor={modo} onChange={setModo} opcoes={[['rs', 'R$'], ['pct', '% da receita']]} /></div>
            <div className="dre-bloco"><span className="dre-bloco-tit">Unidade</span>
              <Segmento valor={unidade} onChange={setUnidade} opcoes={[['inteiro', 'Inteiro'], ['milhar', 'Em milhares']]} /></div>
            <div className="dre-bloco"><span className="dre-bloco-tit">Buscar conta</span>
              <input className="form-control dre-busca" placeholder="nome ou código: comissões, 4.01.01…" value={busca} onChange={e => setBusca(e.target.value)} /></div>
            <div className="dre-acoes">
              <button className={`btn btn-sm ${comVariacao ? 'btn-primary' : 'btn-outline'}`} onClick={() => setComVariacao(v => !v)}>Variação</button>
              <button className={`btn btn-sm ${ocultarZeradas ? 'btn-primary' : 'btn-outline'}`} onClick={() => setOcultarZeradas(v => !v)}>Ocultar zeradas</button>
              <button className="btn btn-outline btn-sm" onClick={() => expandir(true)}>Expandir tudo</button>
              <button className="btn btn-outline btn-sm" onClick={() => expandir(false)}>Recolher tudo</button>
              <button className="btn btn-outline btn-sm" onClick={() => exportarExcel({ D, arvore, meses, grupos: rotuloEmpresas, unidade, visivel, cfg })
                .catch(e => { setEstado('erro'); setErro(`Não foi possível gerar o Excel: ${e.message}`) })}>↓ Excel</button>
              <button className="btn btn-outline btn-sm" onClick={() => window.print()}>Imprimir / PDF</button>
            </div>
          </div>

          <div className="card dre-tabela-wrap">
            <table className="dre-tabela">
              <thead>
                <tr>
                  <th className="dre-col-conta">Conta</th>
                  {colunas === 'mensal' ? <>
                    {meses.map(i => <th key={i}>{D.meses[i]}</th>)}
                    {meses.length > 1 && <th className="dre-col-total">Total período</th>}
                    {meses.length > 1 && comVariacao && <th className="dre-col-var">Variação</th>}
                  </> : <th>Total período</th>}
                </tr>
              </thead>
              <tbody>
                {corpo.length ? corpo : <tr><td colSpan={nCols} className="dre-mudo" style={{ padding: 30, textAlign: 'center' }}>Nenhuma conta encontrada{termo ? ` para "${termo}"` : ''}.</td></tr>}
              </tbody>
            </table>
          </div>
          <div className="dre-rodape">
            Fonte: SAP Business One ({D.empresa}) · modelo financeiro nº {D.modelo} · gerado em {new Date(D.geradoEm).toLocaleString('pt-BR')}
            {D.incluirEncerramento ? ' · inclui o encerramento do exercício' : ' · sem o encerramento do exercício'} · valores sem ajuste de inflação.
            <span className="no-print"> Clique no valor de uma conta para ver fornecedores e lançamentos.</span>
          </div>
        </>
      )}

      {detalhe && <Detalhe cfg={cfg} D={D} grupos={grupos} executar={executar} rotuloEmpresas={rotuloEmpresas}
                           total={somaMeses(arvore.nos.get('a' + detalhe.codigo).monthly, detalhe.meses)} {...detalhe}
                           onFechar={() => setDetalhe(null)} />}
    </div>
  )
}
