import { useEffect, useRef, useState } from 'react'
import { erroApi } from '@hl/ui'
import { TIPOS_DOC, filtrosDetalhe, fmtBRL, fmtPct } from './dados'

// Detalhe de uma conta da DRE: fornecedores/clientes (Parceiros.sql) e, ao clicar, os lançamentos (Lancamentos.sql).
// Só parceiro cadastrado vira item; o resto fica em "Sem fornecedor" (decisão da diretoria: sem conta de contrapartida).
const MAX_TELA = 500   // conta de receita tem dezenas de milhares de clientes — a busca procura em todos

export default function Detalhe({ cfg, D, grupos, executar, rotuloEmpresas, codigo, nome, meses, total, onFechar }) {
  const [itens, setItens] = useState(null)
  const [erro, setErro] = useState('')
  const [busca, setBusca] = useState('')
  const [abertos, setAbertos] = useState({})   // índice -> 'carregando' | {erro} | {itens, truncado, limite}
  const vivo = useRef(true)
  const filtros = filtrosDetalhe(cfg, D, grupos, codigo, meses)

  useEffect(() => {
    vivo.current = true
    executar(cfg.fontes.parceiros, filtros)
      .then(rows => {
        if (!vivo.current) return
        setItens(rows.map(r => ({ origem: r.Origem, parceiro: r.Parceiro || '', nome: r.NomeParceiro || '',
          n: Number(r.N) || 0, valor: Math.round((Number(r.Valor) || 0) * 100) / 100 })))
      })
      .catch(e => { if (vivo.current) setErro(erroApi(e, e.message)) })
    const esc = e => { if (e.key === 'Escape') onFechar() }
    window.addEventListener('keydown', esc)
    return () => { vivo.current = false; window.removeEventListener('keydown', esc) }
  }, [])  // eslint-disable-line react-hooks/exhaustive-deps

  async function alternar(i) {
    if (abertos[i]) { setAbertos(a => { const n = { ...a }; delete n[i]; return n }); return }
    const it = itens[i]
    setAbertos(a => ({ ...a, [i]: 'carregando' }))
    try {
      const rows = await executar(cfg.fontes.lancamentos, { ...filtros, parceiro: it.parceiro, origem: it.origem })
      const limite = cfg.limite_lancamentos || 2000
      const r = { limite, truncado: rows.length > limite, itens: rows.slice(0, limite).map(x => ({
        data: x.Data, lancamento: x.Lancamento, doc: x.Documento || '', tipo: TIPOS_DOC[String(x.TipoDoc)] || `Tipo ${x.TipoDoc}`,
        filial: (x.NomeFilial || String(x.Filial ?? '')).replace('HL DISTRIBUICAO MOTO BIKE LTDA - ', 'HL '),
        valor: Math.round((Number(x.Valor) || 0) * 100) / 100, historico: x.Historico || '', memo: x.Memo || '' })) }
      if (vivo.current) setAbertos(a => ({ ...a, [i]: r }))
    } catch (e) {
      if (vivo.current) setAbertos(a => ({ ...a, [i]: { erro: erroApi(e, e.message) } }))
    }
  }

  const periodo = meses.length === 1 ? D.mesesNome[meses[0]]
    : meses.every((m, k) => k === 0 || m === meses[k - 1] + 1) ? `${D.meses[meses[0]]} a ${D.meses[meses[meses.length - 1]]} (${meses.length} meses)`
      : meses.map(m => D.meses[m]).join(', ')
  const termo = busca.trim().toLowerCase()
  const filtrados = (itens || []).map((it, i) => [it, i]).filter(([it]) => !termo || `${it.nome} ${it.parceiro}`.toLowerCase().includes(termo))
  const somaItens = (itens || []).reduce((a, it) => a + it.valor, 0)
  const maior = (itens || []).reduce((m, it) => Math.max(m, Math.abs(it.valor)), 1)

  return (
    <div className="dre-modal-fundo" onMouseDown={e => { if (e.target === e.currentTarget) onFechar() }}>
      <div className="dre-modal" role="dialog" aria-modal="true">
        <div className="dre-modal-topo">
          <div>
            <div className="dre-mudo">{codigo}</div>
            <h3>{nome}</h3>
            <div className="dre-mudo">{periodo} · {rotuloEmpresas}</div>
          </div>
          <div className="dre-modal-total">
            <div className="dre-mudo">Total</div>
            <div className={total < 0 ? 'dre-neg' : ''}>{fmtBRL(total, 'inteiro')}</div>
            <button className="btn btn-outline btn-sm" onClick={onFechar}>Fechar ✕</button>
          </div>
        </div>
        <div className="dre-modal-barra">
          <input className="form-control dre-busca" placeholder="filtrar fornecedor/cliente…" value={busca} onChange={e => setBusca(e.target.value)} />
          {itens && <span className="dre-mudo">{itens.length.toLocaleString('pt-BR')} fornecedores/clientes · {itens.reduce((a, i) => a + i.n, 0).toLocaleString('pt-BR')} lançamentos · clique numa linha para ver os lançamentos</span>}
        </div>
        <div className="dre-modal-corpo">
          {erro && <div className="alert alert-danger">{erro}</div>}
          {!itens && !erro && <div className="loading-center"><div className="spinner" /></div>}
          {itens && (
            <table className="dre-det">
              <thead><tr><th>Fornecedor / cliente</th><th className="n">Lanç.</th><th className="n">Valor</th><th className="n">% da conta</th></tr></thead>
              <tbody>
                {filtrados.slice(0, MAX_TELA).map(([it, i]) => {
                  const ab = abertos[i]
                  const pct = Math.abs(somaItens) > 0.004 ? it.valor / somaItens * 100 : 0
                  return [
                    <tr key={i} className={`dre-det-parc${ab ? ' aberto' : ''}`} onClick={() => alternar(i)}>
                      <td><span className={`dre-chev${ab ? '' : ' fechado'}`}>▾</span>
                        {it.parceiro ? <>{it.nome}<span className="dre-tag">{it.parceiro}{it.origem === 'MATRIZ' ? ' · MATRIZ' : ''}</span></>
                          : <>Sem fornecedor{it.origem === 'MATRIZ' && <span className="dre-tag">MATRIZ</span>}</>}</td>
                      <td className="n">{it.n.toLocaleString('pt-BR')}</td>
                      <td className={`n ${it.valor < 0 ? 'dre-neg' : ''}`}>{fmtBRL(it.valor, 'inteiro')}</td>
                      <td className="n"><span className="dre-barrinha" style={{ width: Math.round(Math.abs(it.valor) / maior * 60) }} />{fmtPct(pct)}</td>
                    </tr>,
                    ab && (
                      <tr key={`${i}-l`} className="dre-det-lanc"><td colSpan={4}>
                        {ab === 'carregando' && <div className="dre-mudo">Consultando lançamentos…</div>}
                        {ab.erro && <div className="alert alert-danger">{ab.erro}</div>}
                        {ab.itens && (ab.itens.length === 0 ? <div className="dre-mudo">Nenhum lançamento.</div> : (
                          <>
                            <table className="dre-lanc">
                              <thead><tr><th>Data</th><th>Documento</th><th>Lançamento</th><th>Filial</th><th className="n">Valor</th><th>Histórico da linha</th><th>Observação do lançamento</th></tr></thead>
                              <tbody>
                                {ab.itens.map((x, k) => (
                                  <tr key={k}><td>{x.data}</td><td>{x.tipo}{x.doc ? ` ${x.doc}` : ''}</td><td>{x.lancamento}</td><td>{x.filial}</td>
                                    <td className={`n ${x.valor < 0 ? 'dre-neg' : ''}`}>{fmtBRL(x.valor, 'inteiro')}</td><td>{x.historico}</td><td>{x.memo}</td></tr>
                                ))}
                              </tbody>
                            </table>
                            {ab.truncado && <div className="dre-mudo">Mostrando os primeiros {ab.limite.toLocaleString('pt-BR')} lançamentos. Selecione menos meses para ver o restante.</div>}
                          </>
                        ))}
                      </td></tr>
                    ),
                  ]
                })}
                {filtrados.length === 0 && <tr><td colSpan={4} className="dre-mudo">Nenhum fornecedor encontrado.</td></tr>}
                {filtrados.length > MAX_TELA && <tr><td colSpan={4} className="dre-mudo">Mostrando os {MAX_TELA} maiores de {filtrados.length.toLocaleString('pt-BR')}. Use o filtro acima para achar os demais.</td></tr>}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  )
}
