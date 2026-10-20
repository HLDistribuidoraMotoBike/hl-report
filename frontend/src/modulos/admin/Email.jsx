import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { dataHoraCurta, erroApi, salvarConfiguracoes } from '@hl/ui'
import { enviarEmail, historicoEmails, listarEmails, previaEmail, salvarEmail } from './api'
import { Aviso, BotaoConfirmar, Modal } from './comum'

// Configurações → E-mails agendados: liga/desliga, horário, dias, destinatários e assunto de cada e-mail; prévia,
// envio de teste, "Disparar agora" e o histórico. A definição (consulta, modelo, processador, anexo) é código:
// relatorios/email/emails.json.
const DIAS = [['seg', 'Seg'], ['ter', 'Ter'], ['qua', 'Qua'], ['qui', 'Qui'], ['sex', 'Sex'], ['sab', 'Sáb'], ['dom', 'Dom']]
const STATUS = { ok: ['badge-success', 'Enviado'], erro: ['badge-danger', 'Erro'], enviando: ['badge-info', 'Enviando'] }
const TIPO_ENVIO = { agendado: 'Agendado', manual: 'Disparo manual', teste: 'Teste' }

const formularioDe = a => ({ ativo: a.ativo, horario: a.horario, dias_semana: a.dias_semana, assunto: a.assunto,
  destinatarios: (a.destinatarios || []).join('\n') })

function Status({ envio }) {
  if (!envio) return <span className="text-muted">nunca enviado</span>
  const [cls, txt] = STATUS[envio.status] || ['badge-secondary', envio.status]
  return <><span className={`badge ${cls}`}>{txt}</span> {TIPO_ENVIO[envio.tipo] || envio.tipo} · {dataHoraCurta(envio.inicio)}</>
}

function CartaoEmail({ item, somenteTeste, onSalvo, onMsg, onEnviado, onPrevia }) {
  const [form, setForm] = useState(formularioDe(item))
  const [salvando, setSalvando] = useState(false)
  const [enviando, setEnviando] = useState(false)
  const [teste, setTeste] = useState('')
  useEffect(() => { setForm(formularioDe(item)) }, [item])

  const sujo = JSON.stringify(form) !== JSON.stringify(formularioDe(item))
  const lista = form.destinatarios.split(/[\n,;]+/).map(e => e.trim()).filter(Boolean)
  const d = item.definicao || {}

  async function salvar() {
    setSalvando(true)
    try {
      await salvarEmail(item.chave, { ...form, destinatarios: lista })
      onMsg({ tipo: 'ok', texto: `${item.titulo}: salvo.` })
      onSalvo()
    } catch (e) {
      onMsg({ tipo: 'erro', texto: `${item.titulo}: ${erroApi(e)}` })
    } finally {
      setSalvando(false)
    }
  }

  async function enviar(eTeste) {
    setEnviando(true)
    try {
      const { data } = await enviarEmail(item.chave, eTeste ? { teste: true, destinatarios: [teste] } : { teste: false })
      onMsg(data.status === 'ok'
        ? { tipo: 'ok', texto: `${item.titulo}: enviado para ${data.destinatarios.join(', ')}.` }
        : { tipo: 'erro', texto: `${item.titulo}: ${data.erro}` })
      onEnviado()
    } catch (e) {
      onMsg({ tipo: 'erro', texto: `${item.titulo}: ${erroApi(e)}` })
    } finally {
      setEnviando(false)
    }
  }

  const alternarDia = dia => setForm(f => ({ ...f, dias_semana: f.dias_semana.includes(dia) ? f.dias_semana.filter(x => x !== dia) : [...f.dias_semana, dia] }))

  return (
    <div className="card">
      <div className="adm-email-topo">
        <h3>{item.titulo}</h3>
        <label className="adm-chave-liga">
          <input type="checkbox" checked={form.ativo} onChange={e => setForm(f => ({ ...f, ativo: e.target.checked }))} disabled={!item.definido} />
          {form.ativo ? 'Ligado' : 'Desligado'}
        </label>
      </div>
      <div className="adm-chave">{item.chave}{!item.definido && ' — não está mais no emails.json'}</div>

      <div className="adm-grade" style={{ marginTop: '.8rem', gridTemplateColumns: '120px 1fr' }}>
        <div>
          <label className="form-label">Horário</label>
          <input type="time" className="form-control" value={form.horario} onChange={e => setForm(f => ({ ...f, horario: e.target.value }))} />
        </div>
        <div>
          <label className="form-label">Dias</label>
          <div className="adm-dias">
            {DIAS.map(([v, l]) => <button key={v} className={`adm-dia${form.dias_semana.includes(v) ? ' adm-dia--on' : ''}`} onClick={() => alternarDia(v)}>{l}</button>)}
          </div>
        </div>
      </div>
      <label className="form-label">Assunto</label>
      <input className="form-control" value={form.assunto} onChange={e => setForm(f => ({ ...f, assunto: e.target.value }))} />
      <label className="form-label" style={{ marginTop: '.8rem' }}>Destinatários ({lista.length}) — um por linha</label>
      <textarea className="form-control" rows={Math.min(8, Math.max(3, lista.length + 1))} value={form.destinatarios}
                onChange={e => setForm(f => ({ ...f, destinatarios: e.target.value }))} />

      <div className="adm-definicao">
        Consulta: <Link to={`/configuracoes/relatorios`}>{d.sql || '—'}</Link>
        {d.anexo_excel && <> · anexo Excel{d.sql_anexo ? ` (${d.sql_anexo})` : ''}</>}
        <br />Modelo: {d.template || '—'}{d.processador && <> · processador {d.processador}</>}
        {d.filtros && Object.keys(d.filtros).length > 0 && <><br />Filtros: {Object.entries(d.filtros).map(([k, v]) => `${k}=${v || "''"}`).join(', ')}</>}
      </div>

      <div className="adm-envio">Último envio: <Status envio={item.ultimo_envio} />
        {item.ultimo_envio?.status === 'erro' && <div className="text-muted" style={{ marginTop: '.2rem' }}>{item.ultimo_envio.erro}</div>}
      </div>

      <div className="adm-acoes" style={{ marginTop: '.9rem' }}>
        <button className="btn btn-primary btn-sm" onClick={salvar} disabled={!sujo || salvando}>{salvando ? 'Salvando...' : 'Salvar'}</button>
        <button className="btn btn-outline btn-sm" onClick={() => onPrevia(item)} disabled={!item.definido}>Prévia</button>
        {!somenteTeste && (
          <BotaoConfirmar className="btn btn-outline btn-sm" disabled={enviando || !item.definido || !item.destinatarios.length || sujo}
                          confirmar={`Enviar agora para ${item.destinatarios.length}?`} onClick={() => enviar(false)}>
            Disparar agora
          </BotaoConfirmar>
        )}
      </div>
      <div className="adm-acoes" style={{ marginTop: '.5rem' }}>
        <input className="form-control" style={{ maxWidth: 260, padding: '.35rem .6rem', fontSize: '.82rem' }} placeholder="seu e-mail para teste"
               value={teste} onChange={e => setTeste(e.target.value)} />
        <button className="btn btn-outline btn-sm" onClick={() => enviar(true)} disabled={enviando || !teste.trim() || !item.definido}>
          {enviando ? 'Enviando...' : 'Enviar teste'}
        </button>
      </div>
    </div>
  )
}

export default function Email() {
  const [dados, setDados] = useState(null)
  const [historico, setHistorico] = useState([])
  const [msg, setMsg] = useState(null)
  const [previa, setPrevia] = useState(null)   // {titulo, carregando, html, linhas, anexos, erro}

  const carregar = useCallback(() => {
    listarEmails().then(r => setDados(r.data)).catch(e => setMsg({ tipo: 'erro', texto: erroApi(e) }))
    historicoEmails(null, 50).then(r => setHistorico(r.data)).catch(() => {})
  }, [])
  useEffect(() => { carregar() }, [carregar])

  async function abrirPrevia(item) {
    setPrevia({ titulo: item.titulo, carregando: true })
    try {
      const { data } = await previaEmail(item.chave)
      setPrevia({ titulo: item.titulo, ...data })
    } catch (e) {
      setPrevia({ titulo: item.titulo, erro: erroApi(e) })
    }
  }

  async function trocarAgendador(ligar) {
    try {
      await salvarConfiguracoes([{ chave: 'EMAIL_AGENDADOR', valor: ligar ? 'ligado' : 'desligado' }])
      setMsg({ tipo: 'sucesso', texto: `Agendador ${ligar ? 'ligado' : 'desligado'}.` })
      carregar()
    } catch (e) {
      setMsg({ tipo: 'erro', texto: erroApi(e) })
    }
  }

  if (!dados) return <div className="loading-center"><div className="spinner" /></div>

  return (
    <div className="adm-pagina">
      <div className="adm-topo"><h2 className="page-title">E-mails agendados</h2></div>
      <Aviso msg={msg} onFechar={() => setMsg(null)} />
      {dados.somente_teste && (
        <div className="alert alert-info">Ambiente de desenvolvimento: só <strong>envio de teste</strong> (EMAIL_SOMENTE_TESTE) — o SMTP e os destinatários são os reais.</div>
      )}
      <div className={`alert ${dados.agendador_ligado ? 'alert-success' : 'alert-warning'}`}
           style={{ display: 'flex', alignItems: 'center', gap: '1rem', flexWrap: 'wrap' }}>
        <div style={{ flex: 1, minWidth: 240 }}>
          Agendador <strong>{dados.agendador_ligado ? 'LIGADO' : 'DESLIGADO'}</strong>
          {dados.agendador_ligado
            ? ' — os e-mails ligados saem no horário (uma vez por dia; até 30 min depois se o servidor estava parado).'
            : ' — nada sai automaticamente. Ligue só depois de desligar o agendador do Report antigo (senão o e-mail sai em dobro).'}
        </div>
        {!dados.somente_teste && (dados.agendador_ligado
          ? <BotaoConfirmar className="btn btn-outline-secondary btn-sm" confirmar="Desligar? Clique de novo"
                            onClick={() => trocarAgendador(false)}>Desligar agendador</BotaoConfirmar>
          : <BotaoConfirmar className="btn btn-success btn-sm" confirmar="Ligar? Clique de novo"
                            onClick={() => trocarAgendador(true)}>Ligar agendador</BotaoConfirmar>)}
      </div>

      <div className="adm-emails">
        {dados.agendamentos.map(a => (
          <CartaoEmail key={a.chave} item={a} somenteTeste={dados.somente_teste} onSalvo={carregar} onEnviado={carregar}
                       onMsg={setMsg} onPrevia={abrirPrevia} />
        ))}
      </div>

      <div className="adm-secao" style={{ marginTop: '1.5rem' }}>Últimos envios</div>
      <div className="card" style={{ padding: 0, overflow: 'auto' }}>
        <table className="adm-historico">
          <thead><tr><th>Quando</th><th>E-mail</th><th>Tipo</th><th>Por</th><th>Status</th><th>Linhas</th><th>Destinatários / erro</th></tr></thead>
          <tbody>
            {historico.length === 0 && <tr><td colSpan={7} className="text-muted">Nenhum envio ainda.</td></tr>}
            {historico.map(h => {
              const [cls, txt] = STATUS[h.status] || ['badge-secondary', h.status]
              return (
                <tr key={h.id}>
                  <td>{dataHoraCurta(h.inicio)}</td>
                  <td>{h.chave}</td>
                  <td>{TIPO_ENVIO[h.tipo] || h.tipo}</td>
                  <td>{h.usuario}</td>
                  <td><span className={`badge ${cls}`}>{txt}</span></td>
                  <td className="adm-num">{h.linhas ?? '—'}</td>
                  <td className="adm-quebra">{h.status === 'erro' ? h.erro : (h.destinatarios || []).join(', ')}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      {previa && (
        <Modal titulo={`Prévia — ${previa.titulo}`} largura={980} onFechar={() => setPrevia(null)}>
          {previa.carregando && <div className="loading-center"><div className="spinner" /></div>}
          {previa.erro && <div className="alert alert-danger">{previa.erro}</div>}
          {previa.html && (
            <>
              <div className="text-muted" style={{ fontSize: '.8rem', marginBottom: '.5rem' }}>
                Dados de agora: {previa.linhas} linha(s){previa.anexos?.length ? ` · anexo: ${previa.anexos.join(', ')}` : ''}. Nada foi enviado.
              </div>
              <iframe className="adm-previa" title="Prévia do e-mail" srcDoc={previa.html} sandbox="" />
            </>
          )}
        </Modal>
      )}
    </div>
  )
}
