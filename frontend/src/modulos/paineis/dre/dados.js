// Cálculos da DRE Diretoria (sem tela) — portados do DRE.html (07/10/2026, validado contra o gerador antigo) para o
// painel React do HL Report 0.6.0. Mesmas consultas (relatorios/sql/Diretoria/_dre) e mesmas contas:
//   - linhas do modelo financeiro (OFRC) viram uma árvore; as contas (FRC1) ficam penduradas nas linhas;
//   - valor da conta = Crédito − Débito por mês, somado pelos grupos de empresa marcados;
//   - linhas sem fórmula somam as filhas (do nível mais fundo para o topo); fórmulas (Param_1..5 com +/−) na
//     ordem do modelo (uma fórmula pode usar outra anterior);
//   - grupo com um único subgrupo de mesmo nome mostra um nível só.

export const MESES_ABREV = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez']
export const MESES_NOME = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro']

// Tipos de documento (OJDT.TransType) mais comuns, para o detalhamento
export const TIPOS_DOC = {
  '13': 'NF de saída', '14': 'Dev. NF saída', '15': 'Entrega', '16': 'Devolução',
  '18': 'NF de entrada', '19': 'Dev. NF entrada', '20': 'Recebimento merc.', '21': 'Dev. mercadoria',
  '24': 'Contas a receber', '46': 'Contas a pagar', '30': 'Lançamento manual', '59': 'Entrada estoque',
  '60': 'Saída estoque', '67': 'Transferência', '162': 'Reavaliação estoque', '202': 'Ordem de produção',
  '203': 'Adiantamento cliente', '204': 'Adiantamento fornec.', '321': 'Reconciliação', '-3': 'Encerramento',
}

export const ultimoDia = chave => {
  const [a, m] = chave.split('-').map(Number)
  return `${chave}-${String(new Date(a, m, 0).getDate()).padStart(2, '0')}`
}

export function mesesDoPeriodo(ini, fim) {
  const out = []
  let [a, m] = ini.split('-').map(Number)
  const [af, mf] = fim.split('-').map(Number)
  while (a < af || (a === af && m <= mf)) { out.push([a, m]); [a, m] = m === 12 ? [a + 1, 1] : [a, m + 1] }
  return out
}

const listaFiliais = gs => ',' + gs.flatMap(g => g.filiais || []).join(',') + ','

// Grupo de uma linha de saldo: pela origem (SBO_MATRIZ = Especial) ou, na PRD, pela filial; o resto é "base"
function grupoDaLinha(cfg, origem, bpl) {
  const g = (cfg.grupos || []).find(g => (g.origem ? g.origem === origem : (origem === 'PRD' && (g.filiais || []).includes(bpl))))
  return g ? g.chave : 'base'
}

// Consulta o SAP e devolve os dados da DRE do período (mesma estrutura do DRE.html).
// executar(relId, filtros) → linhas; cfg = config do painel
export async function montarDados(executar, cfg, ini, fim, incluirEncerramento) {
  const meses = mesesDoPeriodo(ini, fim)
  const chaves = meses.map(([a, m]) => `${a}-${String(m).padStart(2, '0')}`)
  const f = { modelo: cfg.modelo }
  const enc = incluirEncerramento ? 'S' : 'N'
  const [cats, contas, saldos] = await Promise.all([
    executar(cfg.fontes.modelo, f), executar(cfg.fontes.contas, f),
    executar(cfg.fontes.saldos, { ...f, data_ini: chaves[0] + '-01', data_fim: ultimoDia(chaves[chaves.length - 1]),
      filiais_ocultas: ',' + (cfg.filiais_ocultas || []).join(',') + ',', incluir_encerramento: enc }),
  ])
  if (!cats.length) throw new Error(`Modelo ${cfg.modelo} sem linhas em OFRC.`)
  const linhas = cats.map(c => {
    const params = [1, 2, 3, 4, 5].map(i => c['Param_' + i]).filter(p => p)   // Param_n = 0 quando vazio
    const ops = params.slice(1).map((_, i) => c['Op_' + (i + 1)] || '+')
    return { id: c.CatId, nome: c.Nome, nivel: c.Nivel || 1, pai: c.Pai || null, classe: c.Classe || '',
      formula: params.length ? { params, ops } : null }
  })
  const valores = {}   // conta -> grupo -> [valor por mês]
  saldos.forEach(r => {
    const i = chaves.indexOf(r.Mes)
    if (i < 0) return
    const g = grupoDaLinha(cfg, r.Origem, r.Filial)
    const porGrupo = valores[r.Conta] || (valores[r.Conta] = {})
    ;(porGrupo[g] || (porGrupo[g] = new Array(meses.length).fill(0)))[i] += Number(r.Valor) || 0   // DECIMAL chega como texto
  })
  const [a0, m0] = meses[0], [a1, m1] = meses[meses.length - 1]
  return {
    geradoEm: new Date().toISOString(),
    periodo: a0 === a1 ? `${MESES_NOME[m0 - 1]} – ${MESES_NOME[m1 - 1]} / ${a1}` : `${MESES_NOME[m0 - 1]}/${a0} – ${MESES_NOME[m1 - 1]}/${a1}`,
    inicio: chaves[0], fim: chaves[chaves.length - 1], incluirEncerramento: !!incluirEncerramento,
    empresa: cfg.empresa || '', modelo: cfg.modelo,
    meses: meses.map(([a, m]) => `${MESES_ABREV[m - 1]}/${String(a).slice(2)}`),
    mesesNome: meses.map(([a, m]) => `${MESES_NOME[m - 1]}/${a}`),
    mesesChave: chaves,
    grupos: [{ chave: 'base', rotulo: 'HL Distribuição', detalhe: 'demais filiais', ...cfg.grupo_base, filiais: [] },
      ...(cfg.grupos || []).map(g => ({ chave: g.chave, rotulo: g.rotulo, detalhe: g.detalhe, filiais: g.filiais, origem: g.origem }))],
    linhasChave: cfg.linhas_chave,
    linhas,
    contas: contas.map(c => ({
      codigo: c.Conta, nome: c.Nome, linha: c.CatId, ordem: c.Ordem || 0,
      valores: Object.fromEntries(Object.entries(valores[c.Conta] || {}).map(([g, vs]) => [g, vs.map(v => Math.round(v * 100) / 100)])),
    })),
  }
}

const norm = s => (s || '').trim().toUpperCase()

// Árvore com os valores mensais para os grupos de empresa marcados → {raiz: [nós], nosLinha, nos}
// nó: {key, name, fullName, code, type: group|line|result, monthly: [..], children, conta?, linha?}
export function calcular(D, grupos) {
  const NM = D.meses.length
  const zeros = () => new Array(NM).fill(0)
  const linhaPorId = new Map(D.linhas.map(l => [l.id, l]))
  const nos = new Map(), nosLinha = new Map(), filhosLinha = new Map(), contasLinha = new Map()
  const novoNo = (key, obj) => { const n = { key, monthly: zeros(), children: null, ...obj }; nos.set(key, n); return n }

  D.linhas.forEach(l => {
    nosLinha.set(l.id, novoNo('c' + l.id, { name: l.nome, fullName: l.nome, code: '', linha: l, type: l.formula ? 'result' : 'group' }))
    if (l.pai && l.pai !== l.id && linhaPorId.has(l.pai)) {
      if (!filhosLinha.has(l.pai)) filhosLinha.set(l.pai, [])
      filhosLinha.get(l.pai).push(l.id)
    }
  })
  D.contas.slice().sort((a, b) => a.ordem - b.ordem || a.codigo.localeCompare(b.codigo)).forEach(c => {
    if (!contasLinha.has(c.linha)) contasLinha.set(c.linha, [])
    contasLinha.get(c.linha).push(novoNo('a' + c.codigo, { name: c.nome, fullName: `${c.codigo} - ${c.nome}`, code: c.codigo, conta: c, type: 'line' }))
  })
  const construir = id => {
    const no = nosLinha.get(id)
    if (no.linha.formula) return no
    let kids = (filhosLinha.get(id) || []).map(fid => nosLinha.get(fid)).concat(contasLinha.get(id) || [])
      .map(k => (k.type === 'line' ? k : construir(k.linha.id)))
    while (kids.length === 1 && kids[0].type === 'group' && norm(kids[0].name) === norm(no.name)) kids = kids[0].children || []
    no.children = kids
    return no
  }
  const raiz = D.linhas.filter(l => !l.pai || !linhaPorId.has(l.pai)).map(l => construir(l.id))

  // contas
  D.contas.forEach(c => {
    const n = nos.get('a' + c.codigo)
    grupos.forEach(g => { const v = c.valores[g]; if (v) v.forEach((x, i) => { n.monthly[i] += x }) })
    const ln = nosLinha.get(c.linha)
    if (ln) n.monthly.forEach((x, i) => { ln.monthly[i] += x })
  })
  // soma pela hierarquia: do nível mais profundo para o topo
  D.linhas.slice().sort((a, b) => b.nivel - a.nivel).forEach(l => {
    if (l.formula || !l.pai || !linhaPorId.has(l.pai) || l.pai === l.id) return
    const pai = nosLinha.get(l.pai).monthly, v = nosLinha.get(l.id).monthly
    v.forEach((x, i) => { pai[i] += x })
  })
  // fórmulas, na ordem do modelo
  D.linhas.forEach(l => {
    if (!l.formula) return
    const p = l.formula.params, ops = l.formula.ops
    const out = nosLinha.get(l.id).monthly
    ;(nosLinha.get(p[0])?.monthly || zeros()).forEach((x, i) => { out[i] = x })
    for (let k = 1; k < p.length; k++) {
      const s = ops[k - 1] === '-' ? -1 : 1
      ;(nosLinha.get(p[k])?.monthly || zeros()).forEach((x, i) => { out[i] += s * x })
    }
  })
  return { raiz, nos, nosLinha }
}

export const somaMeses = (monthly, idx) => idx.reduce((a, i) => a + monthly[i], 0)

// Variação entre o último e o primeiro mês selecionado. Resultado (fórmula) e natureza credora: subir é bom;
// natureza devedora (custos/despesas, negativos): a seta acompanha o tamanho da despesa, e despesa maior é ruim.
export function variacao(no, idx) {
  if (idx.length < 2) return null
  const a = no.monthly[idx[0]], b = no.monthly[idx[idx.length - 1]]
  const comoResultado = no.type === 'result' || somaMeses(no.monthly, idx) >= 0
  if (comoResultado) {
    if (Math.abs(a) < 0.005 && Math.abs(b) < 0.005) return { pct: 0, seta: 'flat', cor: 'flat' }
    const delta = b - a
    const pct = Math.abs(a) < 0.005 ? null : (delta / Math.abs(a)) * 100
    const seta = delta > 0.005 ? 'up' : (delta < -0.005 ? 'down' : 'flat')
    return { pct, seta, cor: seta }
  }
  const absA = Math.abs(a), absB = Math.abs(b)
  if (absA < 0.005 && absB < 0.005) return { pct: 0, seta: 'flat', cor: 'flat' }
  const pct = absA < 0.005 ? null : ((absB - absA) / absA) * 100
  const seta = absB > absA ? 'up' : (absB < absA ? 'down' : 'flat')
  return { pct, seta, cor: seta === 'flat' ? 'flat' : (seta === 'up' ? 'down' : 'up') }
}

export function fmtBRL(v, unidade) {
  if (unidade === 'milhar') v = v / 1000
  const neg = v < -0.004
  const s = Math.abs(v).toLocaleString('pt-BR', { minimumFractionDigits: 0, maximumFractionDigits: 0 })
  return neg ? `(${s})` : s
}

export function fmtPct(v) {
  const neg = v < -0.004
  const s = Math.abs(v).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 })
  return neg ? `(${s}%)` : `${s}%`
}

// Filtros das consultas de detalhe (parceiros / lançamentos) para os grupos de empresa marcados
export function filtrosDetalhe(cfg, D, grupos, codigo, meses) {
  const chaves = meses.map(i => D.mesesChave[i])
  return {
    conta: codigo, data_ini: chaves[0] + '-01', data_fim: ultimoDia(chaves[chaves.length - 1]),
    meses: ',' + chaves.join(',') + ',', incluir_base: grupos.has('base') ? 'S' : 'N',
    filiais_grupos: listaFiliais(cfg.grupos || []),
    filiais_incluidas: listaFiliais((cfg.grupos || []).filter(g => grupos.has(g.chave))),
    filiais_ocultas: ',' + (cfg.filiais_ocultas || []).join(',') + ',',
    incluir_matriz: (cfg.grupos || []).some(g => g.origem === 'MATRIZ' && grupos.has(g.chave)) ? 'S' : 'N',
    incluir_encerramento: D.incluirEncerramento ? 'S' : 'N',
  }
}
