import { useEffect, useState } from 'react'
import { formatNum, formatarData, ehDecimalTexto } from '../relatorios/tabela'
import './admin.css'

// Peças das telas de administração do Report.

// Editor de código (SQL/HTML): textarea monoespaçado; Tab insere 4 espaços; Ctrl+S chama onSalvar
export function EditorCodigo({ valor, onChange, onSalvar, linhas = 22, placeholder }) {
  function teclas(e) {
    if (e.key === 'Tab') {
      e.preventDefault()
      const el = e.target, ini = el.selectionStart, fim = el.selectionEnd
      const novo = valor.slice(0, ini) + '    ' + valor.slice(fim)
      onChange(novo)
      requestAnimationFrame(() => { el.selectionStart = el.selectionEnd = ini + 4 })
    } else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
      e.preventDefault()
      onSalvar?.()
    }
  }
  return (
    <textarea className="adm-codigo" value={valor} rows={linhas} spellCheck={false} placeholder={placeholder}
              onChange={e => onChange(e.target.value)} onKeyDown={teclas} />
  )
}

// Botão de ação perigosa: 1º clique pede confirmação no próprio botão (sem janela do navegador)
export function BotaoConfirmar({ children, confirmar = 'Confirmar?', onClick, className = 'btn btn-danger btn-sm', disabled }) {
  const [armado, setArmado] = useState(false)
  useEffect(() => {
    if (!armado) return
    const t = setTimeout(() => setArmado(false), 4000)
    return () => clearTimeout(t)
  }, [armado])
  return (
    <button className={className} disabled={disabled}
            onClick={() => { if (armado) { setArmado(false); onClick() } else setArmado(true) }}>
      {armado ? confirmar : children}
    </button>
  )
}

export function Modal({ titulo, onFechar, children, largura = 520 }) {
  useEffect(() => {
    const esc = e => { if (e.key === 'Escape') onFechar() }
    window.addEventListener('keydown', esc)
    return () => window.removeEventListener('keydown', esc)
  }, [onFechar])
  return (
    <div className="adm-modal-fundo" onMouseDown={e => { if (e.target === e.currentTarget) onFechar() }}>
      <div className="adm-modal" style={{ maxWidth: largura }}>
        <div className="adm-modal-topo">
          <h3>{titulo}</h3>
          <button className="adm-x" onClick={onFechar} aria-label="Fechar">×</button>
        </div>
        {children}
      </div>
    </div>
  )
}

// Resultado de consulta (teste de SQL)
export function TabelaResultado({ colunas, linhas }) {
  if (!colunas.length) return <div className="text-muted">A consulta não devolveu colunas.</div>
  return (
    <div className="adm-resultado">
      <table>
        <thead><tr>{colunas.map(c => <th key={c}>{c}</th>)}</tr></thead>
        <tbody>
          {linhas.length === 0 && <tr><td colSpan={colunas.length} className="text-muted">Nenhuma linha.</td></tr>}
          {linhas.map((l, i) => (
            <tr key={i}>
              {colunas.map(c => {
                const v = l[c]
                const num = typeof v === 'number' || ehDecimalTexto(v)
                return <td key={c} className={num ? 'adm-num' : ''}>{v == null ? '—' : num ? formatNum(v) : formatarData(v)}</td>
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export function Aviso({ msg, onFechar }) {
  if (!msg) return null
  return (
    <div className={`alert ${msg.tipo === 'erro' ? 'alert-danger' : 'alert-success'} adm-aviso`}>
      <span>{msg.texto}</span>
      <button className="adm-x" onClick={onFechar} aria-label="Fechar">×</button>
    </div>
  )
}
