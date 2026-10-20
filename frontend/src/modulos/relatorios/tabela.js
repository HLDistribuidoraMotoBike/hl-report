// Lógica (sem tela) do relatório do tipo lista: formatação, ordenação, agrupamento e exportação.
// Mesmas regras do ListTemplate.html do Report antigo — os relatórios já configurados não mudam.

export const POR_PAGINA = 100
export const SEP = '\u0001'

// DECIMAL do HANA chega como texto ("123.4500") — conta como número na tela e no Excel
export const ehDecimalTexto = v => typeof v === 'string' && /^-?\d+\.\d+$/.test(v)

export function numero(v) {
  if (v === null || v === undefined || v === '') return null
  const n = typeof v === 'number' ? v : Number(v)
  return isNaN(n) ? null : n
}

export function formatNum(v) {
  if (v === null || v === undefined) return '—'
  if (typeof v === 'number') {
    return Number.isInteger(v)
      ? v.toLocaleString('pt-BR')
      : v.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  }
  if (typeof v === 'string') {
    const n = parseFloat(v.replace(',', '.'))
    if (!isNaN(n) && v.includes('.')) return n.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  }
  return v
}

// Data ISO (AAAA-MM-DD) → DD/MM/AAAA só na exibição (ordenação e exportação usam o valor original)
export function formatarData(v) {
  if (typeof v !== 'string') return v
  const m = v.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  return m ? `${m[3]}/${m[2]}/${m[1]}` : v
}

export function compararValores(a, b) {
  if (a == null || a === '') return (b == null || b === '') ? 0 : 1
  if (b == null || b === '') return -1
  const na = numero(a), nb = numero(b)
  if (na !== null && nb !== null) return na - nb
  return String(a).localeCompare(String(b), 'pt-BR', { numeric: true })
}

// Ordenação simples do modo lista/pivot (igual ao Report antigo: comparação direta, vazio por último)
export function compararSimples(a, b, asc) {
  if (a == null) return 1
  if (b == null) return -1
  return asc ? (a > b ? 1 : -1) : (a < b ? 1 : -1)
}

// ── Agrupamento (config.agrupamento) ────────────────────────────────────────
// { niveis: ["Coluna", {coluna, rotulo}], agregacoes: { Col: "soma" | {tipo, coluna, peso, numerador, denominador, casas} },
//   expandido, total_geral, ocultar_colunas_agrupadas, ocultar_colunas_detalhe, titulo }
// tipos: soma, contagem, distintos (coluna pode ser lista), media, media_ponderada (peso), min, max,
//        razao (numerador / denominador = nomes de outras colunas agregadas)
export function lerAgrupamento(config) {
  const a = config.agrupamento
  if ((config.modo || 'lista') === 'pivot' || !a || !(a.niveis || []).length) return null
  return {
    ...a,
    niveis: a.niveis.map(n => typeof n === 'string' ? { coluna: n, rotulo: n } : { coluna: n.coluna, rotulo: n.rotulo || n.coluna }),
    agregacoes: Object.fromEntries(Object.entries(a.agregacoes || {}).map(([c, s]) => [c, typeof s === 'string' ? { tipo: s } : s])),
  }
}

export function agregar(linhas, agregacoes) {
  const res = {}, razoes = []
  for (const [col, spec] of Object.entries(agregacoes)) {
    const src = spec.coluna || col
    const vals = () => linhas.map(r => numero(r[src])).filter(v => v !== null)
    switch (spec.tipo) {
      case 'soma': res[col] = vals().reduce((a, b) => a + b, 0); break
      case 'contagem': res[col] = linhas.length; break
      case 'distintos': {
        const cs = [].concat(src)
        res[col] = new Set(linhas.map(r => cs.map(c => r[c] ?? '').join(SEP))).size
        break
      }
      case 'media': { const v = vals(); res[col] = v.length ? v.reduce((a, b) => a + b, 0) / v.length : null; break }
      case 'min': { const v = vals(); res[col] = v.length ? Math.min(...v) : null; break }
      case 'max': { const v = vals(); res[col] = v.length ? Math.max(...v) : null; break }
      case 'media_ponderada': {
        let sv = 0, sp = 0
        linhas.forEach(r => {
          const v = numero(r[src]), p = numero(r[spec.peso])
          if (v !== null && p !== null) { sv += v * p; sp += p }
        })
        res[col] = sp ? sv / sp : null
        break
      }
      case 'razao': razoes.push([col, spec]); break
      default: break
    }
  }
  razoes.forEach(([col, spec]) => {
    const n = res[spec.numerador], d = res[spec.denominador]
    res[col] = (n != null && d) ? n / d : null
  })
  for (const [col, spec] of Object.entries(agregacoes)) {
    if (typeof res[col] === 'number' && !['contagem', 'distintos'].includes(spec.tipo)) {
      const f = Math.pow(10, spec.casas ?? 2)
      res[col] = Math.round(res[col] * f) / f
    }
  }
  return res
}

// Árvore de grupos a partir das linhas (já filtradas e ordenadas); colunaOrdem = coluna agregada da ordenação
export function montarArvore(linhas, agrup, colunaOrdem, asc) {
  const { niveis, agregacoes } = agrup
  function criar(ls, nivel, chavesPai) {
    const n = niveis[nivel]
    const mapa = new Map()
    ls.forEach(r => {
      const k = r[n.coluna] ?? ''
      if (!mapa.has(k)) mapa.set(k, [])
      mapa.get(k).push(r)
    })
    const nos = [...mapa.entries()].map(([chave, doGrupo]) => {
      const nome = doGrupo[0][n.rotulo] ?? ''
      const rotulo = n.rotulo !== n.coluna ? (nome || chave) : chave
      const chaves = [...chavesPai, { chave, rotulo: nome || chave }]
      const no = {
        nivel, chave, chaves,
        caminho: chaves.map(c => c.chave).join(SEP),
        rotulo: rotulo === '' ? '(vazio)' : formatarData(String(rotulo)),
        sub: n.rotulo !== n.coluna && chave !== '' ? String(chave) : '',
        linhas: doGrupo,
        agg: agregar(doGrupo, agregacoes),
      }
      no.filhos = nivel + 1 < niveis.length ? criar(doGrupo, nivel + 1, chaves) : []
      return no
    })
    if (colunaOrdem && colunaOrdem in agregacoes) {
      nos.sort((a, b) => compararValores(a.agg[colunaOrdem], b.agg[colunaOrdem]) * (asc ? 1 : -1))
    } else {
      nos.sort((a, b) => compararValores(a.rotulo, b.rotulo))
    }
    return nos
  }
  return linhas.length ? criar(linhas, 0, []) : []
}

// Lista do que aparece na tela: [{tipo:'grupo', no} | {tipo:'linha', row}]
export function achatar(arvore, abertos) {
  const saida = []
  ;(function percorrer(nos) {
    nos.forEach(no => {
      saida.push({ tipo: 'grupo', no })
      if (!abertos.has(no.caminho)) return
      if (no.filhos.length) percorrer(no.filhos)
      else no.linhas.forEach(row => saida.push({ tipo: 'linha', row }))
    })
  })(arvore)
  return saida
}

export function todosOsCaminhos(arvore) {
  const s = new Set()
  ;(function percorrer(nos) { nos.forEach(no => { s.add(no.caminho); percorrer(no.filhos) }) })(arvore)
  return s
}

// Colunas do modo agrupado: sem as colunas usadas nos níveis (padrão)
export function colunasExibidas(colunas, agrup) {
  if (agrup.ocultar_colunas_agrupadas === false) return colunas
  const ocultas = new Set(agrup.niveis.flatMap(n => [n.coluna, n.rotulo]))
  return colunas.filter(c => !ocultas.has(c))
}

// Colunas sem totalização só aparecem com alguma linha de detalhe aberta (ou com filtro ativo nelas)
export function colunasVisiveis(colunas, agrup, visiveis, filtrosCol) {
  const base = colunasExibidas(colunas, agrup)
  if (agrup.ocultar_colunas_detalhe === false) return base
  if (visiveis.some(item => item.tipo === 'linha')) return base
  return base.filter(c => c in agrup.agregacoes || filtrosCol[c])
}

// Rótulos dos meses do pivot ("AAAA-MM")
export function rotulosDeMes(json, colsMesLabel) {
  const locais = () => Array.from({ length: colsMesLabel.length }, (_, i) => {
    const d = new Date(); d.setDate(1); d.setMonth(d.getMonth() - i)
    return d.toISOString().slice(0, 7)
  })
  if (json.mes_labels && Object.keys(json.mes_labels).length > 0) return colsMesLabel.map(c => json.mes_labels[c] || c)
  if (json.data.length > 0) {
    const row = json.data[0]
    const ls = colsMesLabel.map(c => {
      const val = String(row[c] || '')
      return val.match(/\d{4}-\d{2}/) ? val.slice(0, 7) : null
    })
    return ls.some(l => !l) ? locais() : ls
  }
  return locais()
}

export function nomeDoMes(mes) {
  const partes = mes.split('-')
  if (partes.length !== 2) return mes
  return new Date(parseInt(partes[0]), parseInt(partes[1]) - 1, 1)
    .toLocaleDateString('pt-BR', { month: 'short', year: 'numeric' }).replace('.', '').toUpperCase()
}

// ── Exportação ─────────────────────────────────────────────────────────────
export function baixarCsv(nome, cabecalho, linhas) {
  const corpo = linhas.map(l => l.map(v => `"${v ?? ''}"`).join(';'))
  const blob = new Blob(['﻿' + cabecalho.join(';') + '\n' + corpo.join('\n')], { type: 'text/csv;charset=utf-8' })
  const a = Object.assign(document.createElement('a'), { href: URL.createObjectURL(blob), download: `${nome}.csv` })
  document.body.appendChild(a); a.click(); a.remove()
  setTimeout(() => URL.revokeObjectURL(a.href), 10000)
}

export async function baixarExcel(nome, abas) {
  const XLSX = await import('xlsx')   // biblioteca grande: só carrega quando exporta
  const wb = XLSX.utils.book_new()
  abas.forEach(([titulo, linhas]) => XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(linhas),
    titulo.replace(/[:\\/?*[\]]/g, '').slice(0, 31) || 'Relatório'))
  XLSX.writeFile(wb, `${nome}.xlsx`)
}
