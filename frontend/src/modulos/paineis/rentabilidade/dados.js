// Cálculos do painel de Rentabilidade (sem tela). Mesmas contas das páginas antigas RentabilidadeEcommerce.html /
// RentabilidadeConsolidado.html (até a 0.2.0), agora sobre as duas fontes:
//   ecommerce   — lógica legada do E-commerce (ICMS Presumido é imposto: entra em "Total Impostos")
//   consolidado — HL_RENTABILIDADE, todas as empresas e canais (ICMS Presumido é CRÉDITO: fica fora dos impostos)

const n = v => Number(v) || 0
const t = v => (v == null ? '' : String(v))

export function mapear(r) {
  return {
    filial: t(r['Filial']), canal: t(r['Canal']), setor: t(r['Setor']),
    docEntry: t(r['DocEntry']), loja: t(r['Loja']), nf: t(r['NF']), uf: t(r['UF']),
    data: t(r['Data Emissao']).slice(0, 10), hora: t(r['Hora Emissao']),
    itemCode: t(r['Item Code']), produto: t(r['Produto']), marca: t(r['Marca']),
    qtd: n(r['Quantidade']), vlr: n(r['Vlr Anunciado']), comissao: n(r['Comissao']), frete: n(r['Frete']),
    credPirelli: n(r['Total Cred. Pirelli']), vlrNF: n(r['Vlr de NF']),
    icms: n(r['Vlr. Icms destacado']), difal: n(r['Difal']), pis: n(r['Vlr. Pis']), cofins: n(r['Vlr Cofins']),
    ipi: n(r['Vlr IPI']), presumido: n(r['ICMS Presumido']), transferencia: n(r['ICMS Transferencia']),
    impostos: n(r['Total Impostos']), despOp: n(r['Total Desp. Operacional']), receitaBruta: n(r['Receita']),
    receita: n(r['Receita Liquido Com Credito']), mkp: n(r['Mkp Receita Com Credito']),
  }
}

// Canal do consolidado: Atacado se divide pelo setor do vendedor (Bike/Moto), como no e-mail
export const nomeCanal = l => (l.canal ? (l.setor ? `${l.canal} - ${l.setor}` : l.canal) : 'Sem canal')

const novoGrupo = extra => ({ freq: 0, qtd: 0, vlr: 0, receita: 0, impostos: 0, mkpSoma: 0, linhas: [], ...extra })

function somar(g, l) {
  g.freq++
  g.qtd += l.qtd
  g.vlr += l.vlr
  g.receita += l.receita
  g.impostos += l.impostos
  g.mkpSoma += l.mkp
  g.linhas.push(l)
}

export const margem = g => (g.vlr > 0 ? (g.receita / g.vlr) * 100 : 0)
// "Mkp médio" = média simples do markup das linhas (como nas páginas antigas)
export const mkpMedio = g => g.mkpSoma / Math.max(g.freq, 1)

export function agregar(linhas) {
  const tot = { vlr: 0, receita: 0, credPirelli: 0, vlrNF: 0, impostos: 0, receitaBruta: 0, despOp: 0,
    icms: 0, difal: 0, pis: 0, cofins: 0, ipi: 0, presumido: 0, transferencia: 0 }
  const mapas = { loja: new Map(), uf: new Map(), marca: new Map(), canal: new Map(), produto: new Map(), nota: new Map() }
  const grupo = (mapa, chave, extra) => {
    if (!mapas[mapa].has(chave)) mapas[mapa].set(chave, novoGrupo({ chave, ...extra }))
    return mapas[mapa].get(chave)
  }
  for (const l of linhas) {
    for (const k of Object.keys(tot)) tot[k] += l[k]
    somar(grupo('loja', l.loja), l)
    somar(grupo('uf', l.uf), l)
    somar(grupo('marca', l.marca), l)
    somar(grupo('canal', nomeCanal(l)), l)
    somar(grupo('produto', l.itemCode, { produto: l.produto, marca: l.marca }), l)
    somar(grupo('nota', l.docEntry, { nf: l.nf, loja: l.loja, uf: l.uf, data: l.data, hora: l.hora, canal: nomeCanal(l) }), l)
  }
  const lista = m => [...m.values()]
  return {
    tot, linhas: linhas.length,
    lojas: lista(mapas.loja), ufs: lista(mapas.uf), marcas: lista(mapas.marca), canais: lista(mapas.canal),
    produtos: lista(mapas.produto), notas: lista(mapas.nota),
  }
}

// Gráfico de barras: 5 maiores por valor anunciado + "Outros"
export function top5(grupos) {
  const ord = [...grupos].sort((a, b) => b.vlr - a.vlr)
  const top = ord.slice(0, 5).map(g => ({ nome: g.chave || '(vazio)', vlr: g.vlr, receita: g.receita }))
  const resto = ord.slice(5)
  if (resto.length) top.push({ nome: 'Outros', vlr: resto.reduce((a, g) => a + g.vlr, 0), receita: resto.reduce((a, g) => a + g.receita, 0) })
  return top
}

// Ordenação das tabelas (Produtos, Marcas, Notas)
export function ordenar(grupos, coluna, asc) {
  const valor = {
    freq: g => g.freq, qtd: g => g.qtd, vlr: g => g.vlr, receita: g => g.receita, impostos: g => g.impostos,
    margem, mkp: mkpMedio, data: g => `${g.data} ${g.hora}`,
  }[coluna] || (() => 0)
  return [...grupos].sort((a, b) => {
    const va = valor(a), vb = valor(b)
    const d = va < vb ? -1 : va > vb ? 1 : 0
    return asc ? d : -d
  })
}

export const brl = v => (v || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
export const num = (v, casas = 2) => (v || 0).toLocaleString('pt-BR', { minimumFractionDigits: casas, maximumFractionDigits: casas })
export const dataBr = d => (d && /^\d{4}-\d{2}-\d{2}/.test(d) ? `${d.slice(8, 10)}/${d.slice(5, 7)}/${d.slice(0, 4)}` : d || '—')
export const classeMargem = v => (v >= 25 ? 'bom' : v >= 10 ? 'ok' : 'ruim')
export const classeMkp = v => (v >= 1.3 ? 'bom' : v >= 1.1 ? 'ok' : 'ruim')
