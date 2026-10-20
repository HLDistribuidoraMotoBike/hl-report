import { api } from '@hl/ui'

const caminho = id => id.split('/').map(encodeURIComponent).join('/')

// Relatórios (arquivos)
export const getArvore = () => api.get('/admin/arvore')
export const criarPasta = nome => api.post('/admin/pastas', { nome })
export const excluirPasta = nome => api.delete(`/admin/pastas/${encodeURIComponent(nome)}`)
export const lerSql = id => api.get(`/admin/sql/${caminho(id)}`)
export const salvarSql = dados => api.put('/admin/sql', dados)
export const excluirSql = id => api.delete(`/admin/sql/${caminho(id)}`)
export const testarSql = (sql, filtros, schema) => api.post('/admin/testar-sql', { sql, filtros, schema })

// Templates: tipo = relatorio (página de indicador) | email
export const listarTemplates = tipo => api.get(`/admin/templates/${tipo}`)
export const lerTemplate = (tipo, nome) => api.get(`/admin/templates/${tipo}/${encodeURIComponent(nome)}`)
export const salvarTemplate = (tipo, dados) => api.put(`/admin/templates/${tipo}`, dados)
export const excluirTemplate = (tipo, nome) => api.delete(`/admin/templates/${tipo}/${encodeURIComponent(nome)}`)

// E-mails agendados
export const listarEmails = () => api.get('/email/agendamentos')
export const salvarEmail = (chave, dados) => api.put(`/email/agendamentos/${encodeURIComponent(chave)}`, dados)
export const previaEmail = chave => api.post(`/email/agendamentos/${encodeURIComponent(chave)}/previa`)
export const enviarEmail = (chave, dados) => api.post(`/email/agendamentos/${encodeURIComponent(chave)}/enviar`, dados)
export const historicoEmails = (chave, limite = 50) => api.get('/email/envios', { params: { chave: chave || undefined, limite } })

// Nomes dos :filtros do SQL (ignora linhas de comentário) — mesma regra do servidor
export function parametrosDoSql(sql) {
  const vistos = []
  for (const linha of (sql || '').split('\n')) {
    if (linha.trim().startsWith('--')) continue
    for (const m of linha.matchAll(/:([a-zA-Z_]+)/g)) if (!vistos.includes(m[1])) vistos.push(m[1])
  }
  return vistos
}
