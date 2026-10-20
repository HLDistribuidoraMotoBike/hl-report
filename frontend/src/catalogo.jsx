import { createContext, useCallback, useContext, useEffect, useState } from 'react'
import { useAuth } from '@hl/ui'
import { listarRelatorios } from './modulos/relatorios/api'

// Catálogo (pastas → relatórios que o usuário pode ver): monta o menu e a tela inicial. As telas de administração
// chamam recarregar() depois de criar/excluir relatório ou pasta.
const CatalogoContext = createContext({ catalogo: null, recarregar: () => {} })

export function CatalogoProvider({ children }) {
  const { token } = useAuth()
  const [catalogo, setCatalogo] = useState(null)
  const recarregar = useCallback(() => {
    if (!token) { setCatalogo(null); return }
    listarRelatorios().then(r => setCatalogo(r.data)).catch(() => setCatalogo([]))
  }, [token])
  useEffect(() => { recarregar() }, [recarregar])
  return <CatalogoContext.Provider value={{ catalogo, recarregar }}>{children}</CatalogoContext.Provider>
}

export const useCatalogo = () => useContext(CatalogoContext).catalogo
export const useRecarregarCatalogo = () => useContext(CatalogoContext).recarregar
