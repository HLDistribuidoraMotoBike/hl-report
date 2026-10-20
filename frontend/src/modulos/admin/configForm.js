// Configuração do relatório (JSON) ⇄ formulário da tela Configurações → Relatórios.
export const TIPOS_FILTRO = [['text', 'Texto'], ['date', 'Data'], ['number', 'Número'], ['select', 'Lista']]
const CONHECIDOS = ['titulo', 'tipo', 'template', 'schema', 'filtros']

// config (JSON) ⇄ formulário: campos conhecidos no formulário, o resto no JSON avançado (pivot, agrupamento, DRE...)
export function paraFormulario(config, nome) {
  const c = config || {}
  const resto = Object.fromEntries(Object.entries(c).filter(([k]) => !CONHECIDOS.includes(k)))
  return {
    usaConfig: config != null,
    ordem: Object.keys(c),   // ao salvar, as chaves voltam na ordem do arquivo (diferença limpa no git)
    titulo: c.titulo ?? nome, tipo: c.tipo || 'lista', template: c.template || '', schema: c.schema || '',
    filtros: (c.filtros || []).map(f => ({
      id: f.id || '', label: f.label || '', tipo: f.tipo || 'text', placeholder: f.placeholder || '',
      opcoes: (f.opcoes || []).map(o => typeof o === 'object' ? `${o.value ?? ''} | ${o.label ?? ''}` : String(o)).join('\n'),
      extra: Object.fromEntries(Object.entries(f).filter(([k]) => !['id', 'label', 'tipo', 'placeholder', 'opcoes'].includes(k))),
    })),
    avancado: Object.keys(resto).length ? JSON.stringify(resto, null, 2) : '{}',
  }
}

export function paraConfig(form) {
  if (!form.usaConfig) return null
  let resto
  try {
    resto = JSON.parse(form.avancado || '{}')
  } catch (e) {
    throw new Error(`JSON avançado inválido: ${e.message}`)
  }
  if (!resto || typeof resto !== 'object' || Array.isArray(resto)) throw new Error('O JSON avançado precisa ser um objeto { ... }.')
  const filtros = form.filtros.map((f, i) => {
    if (!f.id.trim()) throw new Error(`Filtro ${i + 1}: informe o id (o :nome usado no SQL).`)
    const saida = { id: f.id.trim(), label: f.label.trim() || f.id.trim(), tipo: f.tipo, ...f.extra }
    if (f.placeholder.trim()) saida.placeholder = f.placeholder.trim()
    if (f.tipo === 'select') {
      saida.opcoes = f.opcoes.split('\n').map(l => l.trim()).filter(Boolean).map(l => {
        const [v, ...r] = l.split('|')
        return r.length ? { value: v.trim(), label: r.join('|').trim() } : v.trim()
      })
    }
    return saida
  })
  if (form.tipo === 'painel') {
    const novo = { titulo: form.titulo.trim(), tipo: 'painel', ...resto }
    const final = {}
    for (const k of form.ordem || []) if (k in novo) final[k] = novo[k]
    return Object.assign(final, novo)
  }
  const cfg = { titulo: form.titulo.trim(), tipo: form.tipo }
  if (form.tipo === 'indicador' && form.template) cfg.template = form.template
  if (form.schema.trim()) cfg.schema = form.schema.trim()
  cfg.filtros = filtros
  const novo = { ...cfg, ...resto }
  const final = {}
  for (const k of form.ordem || []) if (k in novo) final[k] = novo[k]
  return Object.assign(final, novo)
}
