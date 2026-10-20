import { lazy } from 'react'

// Painéis (relatórios do tipo "painel"): config.componente → tela React. Cada painel consulta as fontes do config.
export const PAINEIS = {
  rentabilidade: lazy(() => import('./rentabilidade/Rentabilidade')),
}
