import { lazy, Suspense, useEffect, useState } from 'react'
import { BrowserRouter, Routes, Route, Navigate, Link } from 'react-router-dom'
import { AuthProvider, AvisoNovaVersao, Layout, Login, Admin, Configuracoes, RotaPrivada, useAuth, GRUPOS_INTEGRACOES } from '@hl/ui'
import { listarPastas, rotaDoRelatorio } from './modulos/relatorios/api'
import { CatalogoProvider, useCatalogo } from './catalogo'

const Relatorio = lazy(() => import('./modulos/relatorios/Relatorio'))
const AdminRelatorios = lazy(() => import('./modulos/admin/Relatorios'))
const AdminTemplates = lazy(() => import('./modulos/admin/Templates'))
const AdminEmail = lazy(() => import('./modulos/admin/Email'))

const SISTEMA = 'HL Report'

// Papéis (mesmos do backend: app/permissoes.py). Os recursos são as PASTAS de relatórios (vêm do servidor).
const PAPEIS = [
  { value: 'admin',   label: 'Administrador', cor: '#6c5ce7', bg: '#f0eeff' },
  { value: 'usuario', label: 'Usuário',       cor: '#00b894', bg: '#e8faf5' },
]

// Configurações → API: conexão com o SAP HANA, e-mail (SMTP + agendador) e atalhos para os outros apps
const GRUPOS_CONFIG = {
  hana: { label: 'SAP HANA', descricao: 'Conexão direta com o banco do SAP (só leitura) — todos os relatórios usam' },
  smtp: { label: 'E-mail', descricao: 'SMTP dos e-mails agendados e o agendador (ligado | desligado). Ligue o agendador SÓ depois de desligar o do Report antigo — senão o e-mail sai em dobro' },
  apps: GRUPOS_INTEGRACOES.apps,
}

const CONFIGURACOES = {
  key: 'configuracoes', label: 'Configurações',
  items: [
    { label: 'Relatórios', path: '/configuracoes/relatorios' },
    { label: 'Templates', path: '/configuracoes/templates' },
    { label: 'E-mails agendados', path: '/configuracoes/email' },
    { label: 'API', path: '/configuracoes/api' },
  ],
}

function Inicio() {
  const { user } = useAuth()
  const catalogo = useCatalogo()
  return (
    <div className="page-wrapper" style={{ maxWidth: 1100 }}>
      <div className="page-header">
        <h2 className="page-title">Olá, {user?.display_name?.split(' ')[0]}</h2>
        <p className="page-subtitle">Relatórios da HLMotobike (SAP HANA).</p>
      </div>
      {catalogo === null && <div className="loading-center"><div className="spinner" /></div>}
      {catalogo?.length === 0 && <div className="alert alert-info">Seu usuário ainda não tem relatórios liberados. Fale com o administrador.</div>}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: '1rem' }}>
        {(catalogo || []).map(p => (
          <div key={p.pasta} className="card">
            <h3 style={{ fontSize: '1rem', marginBottom: '.75rem' }}>{p.pasta}</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '.35rem' }}>
              {p.relatorios.map(r => (
                <Link key={r.id} to={rotaDoRelatorio(r.id)} style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '.9rem' }}>
                  {r.tipo === 'indicador' ? '📊' : '📋'} {r.titulo}
                </Link>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

// Admin → Grupos: cada pasta de relatórios é um recurso
function AdminReport() {
  const [recursos, setRecursos] = useState(null)
  useEffect(() => {
    listarPastas()
      .then(r => setRecursos(r.data.map(p => ({ key: p, label: p, desc: `Relatórios da pasta ${p}` }))))
      .catch(() => setRecursos([]))
  }, [])
  if (recursos === null) return <div className="loading-center"><div className="spinner" /></div>
  return <Admin papeis={PAPEIS} recursos={recursos} exemploNome="Ex: Financeiro-hl" />
}

function Pagina({ children, admin }) {
  const catalogo = useCatalogo()
  const menu = (catalogo || []).map(p => ({
    key: p.pasta, label: p.pasta,
    items: p.relatorios.map(r => ({ label: r.titulo, path: rotaDoRelatorio(r.id) })),
  }))
  return (
    <RotaPrivada admin={admin}>
      <Layout sistema={SISTEMA} menu={menu} configuracoes={CONFIGURACOES}>
        <Suspense fallback={<div className="loading-center"><div className="spinner" /></div>}>{children}</Suspense>
      </Layout>
    </RotaPrivada>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <CatalogoProvider>
        <AvisoNovaVersao />
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<Login sistema={SISTEMA} icone="📊" />} />
            <Route path="/" element={<Pagina><Inicio /></Pagina>} />
            <Route path="/r/*" element={<Pagina><Relatorio /></Pagina>} />
            <Route path="/admin" element={<Pagina admin><AdminReport /></Pagina>} />
            <Route path="/configuracoes/relatorios" element={<Pagina admin><AdminRelatorios /></Pagina>} />
            <Route path="/configuracoes/templates" element={<Pagina admin><AdminTemplates /></Pagina>} />
            <Route path="/configuracoes/email" element={<Pagina admin><AdminEmail /></Pagina>} />
            <Route path="/configuracoes/api" element={<Pagina admin><Configuracoes grupos={GRUPOS_CONFIG} /></Pagina>} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </BrowserRouter>
      </CatalogoProvider>
    </AuthProvider>
  )
}
