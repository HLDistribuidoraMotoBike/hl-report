import { api } from '@hl/ui'

// id do relatório = "Pasta/Nome"; cada parte vai codificada no endereço
const caminho = relId => relId.split('/').map(encodeURIComponent).join('/')

export const listarRelatorios = () => api.get('/relatorios')
export const listarPastas = () => api.get('/relatorios/pastas')
export const getConfig = relId => api.get(`/config/${caminho(relId)}`)
// Erro de execução volta no formato do Report antigo ({ok: false, erro}) — a tela lê o corpo mesmo com status de erro
export const executar = (relId, filtros) =>
  api.get(`/executar/${caminho(relId)}`, { params: filtros, validateStatus: s => s !== 401 })
export const abrirPagina = relId => api.post('/relatorios/pagina', { rel_id: relId })

// Rota da tela de um relatório: /r/<Pasta>/<Nome>
export const rotaDoRelatorio = relId => `/r/${caminho(relId)}`

// Cliente das páginas de indicador (iframe): cada fetch("/api/...") delas passa por aqui — mesmo login e renovação do
// token da tela (ver backend app/modulos/relatorios/paginas.py)
export function registrarClienteDasPaginas() {
  window.__hlFetch = async (url, opcoes = {}) => {
    const u = new URL(url, window.location.origin)
    const r = await api.request({
      url: u.pathname.replace(/^\/api/, '') + u.search,
      method: opcoes.method || 'GET',
      data: opcoes.body,
      headers: opcoes.headers instanceof Headers ? Object.fromEntries(opcoes.headers.entries()) : opcoes.headers,
      responseType: 'text',
      transformResponse: x => x,
      validateStatus: s => s !== 401,
    })
    return new Response(r.data, { status: r.status, headers: { 'Content-Type': r.headers['content-type'] || 'application/json' } })
  }
}
