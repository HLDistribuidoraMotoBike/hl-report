"""Páginas próprias dos relatórios do tipo "indicador" (DRE, Rentabilidade, Simulador...): o HTML vem de
relatorios/templates/ e é montado com Jinja como no Report antigo (variáveis nome, rel_id, config).

A tela React mostra a página num iframe do mesmo endereço. Como o iframe não manda o cabeçalho de login:
- o endereço da página leva um PASSE (?t=) assinado, que vale só para aquela página e só abre o HTML (sem dados);
- um script colocado no começo da página faz cada fetch("/api/...") dela passar pelo cliente da tela de fora
  (window.parent.__hlFetch: mesmo login, renovação do token) — ou, aberta sozinha, usa o token salvo no navegador;
- dentro do iframe, os links "← Voltar" (href="/") somem: o menu do app já faz esse papel.
"""
import re
from datetime import datetime, timedelta
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape
from jose import JWTError, jwt

from hlcore import auth
from hlcore.erros import ErroNegocio

from app.modulos.relatorios import catalogo

VALIDADE_PASSE_HORAS = 12
COMPAT = Path(__file__).parent / "compat"   # base.html/tema.html do Report antigo ({% extends "base.html" %})

ROTEADOR = """<script>/* HL Report: chamadas /api desta página com o login do app */
(function () {
  if (window.parent !== window) document.documentElement.classList.add('hl-embutido');
  var original = window.fetch.bind(window);
  window.fetch = function (entrada, opcoes) {
    var url = typeof entrada === 'string' ? entrada : (entrada && entrada.url) || '';
    if (url.indexOf('/api/') !== 0 && url.indexOf(location.origin + '/api/') !== 0) return original(entrada, opcoes);
    try { if (window.parent !== window && window.parent.__hlFetch) return window.parent.__hlFetch(url, opcoes); } catch (e) {}
    opcoes = Object.assign({}, opcoes);
    var cab = new Headers(opcoes.headers || {}), token = null;
    try { token = localStorage.getItem('token'); } catch (e) {}
    if (token) cab.set('Authorization', 'Bearer ' + token);
    opcoes.headers = cab;
    return original(entrada, opcoes);
  };
})();
</script>
<style>.hl-embutido a[href="/"] { display: none !important; }</style>
"""


def criar_passe(username: str, rel_id: str) -> str:
    payload = {"sub": username, "rel": rel_id, "tipo": "pagina",
               "exp": datetime.utcnow() + timedelta(hours=VALIDADE_PASSE_HORAS)}
    return jwt.encode(payload, auth.JWT_SECRET, algorithm=auth.JWT_ALGORITHM)


def conferir_passe(passe: str, rel_id: str) -> str:
    try:
        payload = jwt.decode(passe or "", auth.JWT_SECRET, algorithms=[auth.JWT_ALGORITHM])
    except JWTError:
        raise ErroNegocio("Passe da página inválido ou vencido — abra o relatório de novo pelo menu.", "PASSE_INVALIDO", 401)
    if payload.get("tipo") != "pagina" or payload.get("rel") != rel_id:
        raise ErroNegocio("Passe de outra página.", "PASSE_INVALIDO", 401)
    return payload["sub"]


def _ambiente() -> Environment:
    # autoescape ligado: mesmo comportamento do render_template_string do Flask
    return Environment(loader=FileSystemLoader([str(catalogo.pasta_templates()), str(COMPAT)]),
                       autoescape=select_autoescape(default_for_string=True, default=True))


def _injetar(html: str) -> str:
    m = re.search(r"<head[^>]*>", html, flags=re.IGNORECASE)
    if m:
        return html[:m.end()] + "\n" + ROTEADOR + html[m.end():]
    return ROTEADOR + html


def montar(rel_id: str) -> str:
    cfg = catalogo.carregar_config(rel_id)
    if cfg.get("tipo") != "indicador":
        raise ErroNegocio("Este relatório não tem página própria.", "NAO_E_INDICADOR", 400)
    nome = catalogo.separar(rel_id)[1]
    caminho = catalogo.caminho_template(cfg.get("template") or f"{nome}.html")
    if not caminho.is_file():
        raise ErroNegocio(f"Página do relatório não encontrada ({caminho.name}).", "PAGINA_NAO_ENCONTRADA", 404)
    html = _ambiente().from_string(caminho.read_text(encoding="utf-8-sig")).render(nome=nome, rel_id=rel_id, config=cfg)
    return _injetar(html)
