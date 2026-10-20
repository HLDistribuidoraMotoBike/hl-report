// Exportação da DRE para Excel (.xlsx): aba "DRE" com a árvore do modelo (níveis agrupados — botões +/− do Excel),
// os meses marcados, total e % da receita; aba "Parâmetros" com período, empresas e opções. Valores em R$ (ou mil).
import { somaMeses } from './dados'

export async function exportarExcel({ D, arvore, meses, grupos, unidade, visivel, cfg }) {
  const XLSX = await import('xlsx')
  const div = unidade === 'milhar' ? 1000 : 1
  const r = v => Math.round(v / div * 100) / 100   // centavos (sem resíduo de ponto flutuante)
  const fmt = unidade === 'milhar' ? '#,##0.0;(#,##0.0)' : '#,##0;(#,##0)'
  const receita = somaMeses(arvore.nosLinha.get(D.linhasChave.receita_liquida).monthly, meses)

  const cab = ['Código', 'Conta', ...meses.map(i => D.meses[i]), ...(meses.length > 1 ? ['Total período'] : []), '% da receita']
  const linhas = [cab]
  const niveis = [0]
  ;(function percorrer(nos, nivel) {
    for (const no of nos) {
      if (!visivel(no)) continue
      const total = somaMeses(no.monthly, meses)
      linhas.push([no.code || '', `${'   '.repeat(nivel)}${no.name}`, ...meses.map(i => r(no.monthly[i])),
        ...(meses.length > 1 ? [r(total)] : []), Math.abs(receita) > 0.001 ? total / receita : null])
      niveis.push(nivel)
      if (no.children?.length) percorrer(no.children, nivel + 1)
    }
  })(arvore.raiz, 0)

  const ws = XLSX.utils.aoa_to_sheet(linhas)
  const nNum = meses.length + (meses.length > 1 ? 1 : 0)
  for (let r = 1; r < linhas.length; r++) {
    for (let c = 2; c < 2 + nNum; c++) { const cel = ws[XLSX.utils.encode_cell({ r, c })]; if (cel && cel.t === 'n') cel.z = fmt }
    const pc = ws[XLSX.utils.encode_cell({ r, c: 2 + nNum })]
    if (pc && pc.t === 'n') pc.z = '0.0%;(0.0%)'
  }
  ws['!cols'] = [{ wch: 12 }, { wch: 52 }, ...Array(nNum).fill({ wch: 14 }), { wch: 11 }]
  ws['!rows'] = niveis.map(l => (l > 0 ? { level: Math.min(l, 7) } : {}))
  ws['!freeze'] = { xSplit: 2, ySplit: 1 }

  const par = XLSX.utils.aoa_to_sheet([
    ['DRE Diretoria'],
    ['Período', D.periodo],
    ['Meses', meses.map(i => D.meses[i]).join(', ')],
    ['Empresas', grupos],
    ['Encerramento do exercício', D.incluirEncerramento ? 'incluído' : 'excluído (lançamentos tipo -3 do SAP)'],
    ['Valores', unidade === 'milhar' ? 'R$ mil' : 'R$'],
    ['Fonte', `SAP Business One (${D.empresa}) · modelo financeiro nº ${D.modelo}`],
    ['Gerado em', new Date(D.geradoEm).toLocaleString('pt-BR')],
    ['Contas', `${cfg.titulo || 'DRE'} — Crédito − Débito por mês (regime de competência); valores sem ajuste de inflação`],
  ])
  par['!cols'] = [{ wch: 26 }, { wch: 80 }]

  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'DRE')
  XLSX.utils.book_append_sheet(wb, par, 'Parâmetros')
  XLSX.writeFile(wb, `DRE ${D.mesesChave[meses[0]]} a ${D.mesesChave[meses[meses.length - 1]]}.xlsx`)
}
