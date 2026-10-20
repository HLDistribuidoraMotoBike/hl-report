from datetime import datetime


def _fmt_moeda(v):
    v = v or 0
    if abs(v) >= 1_000_000:
        return f"R$ {v/1_000_000:.1f}M".replace(".", ",")
    if abs(v) >= 1_000:
        return f"R$ {v/1_000:.1f}k".replace(".", ",")
    return f"R$ {v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def _fmt_pct(v):
    return f"{(v or 0):.2f}%".replace(".", ",")


def _fmt_int(v):
    return f"{int(v or 0):,}".replace(",", ".")


def preparar_contexto(dados_raw, relatorio, filtros):
    total_anunciado = sum(float(r.get("Vlr Anunciado") or 0) for r in dados_raw)
    total_receita   = sum(float(r.get("Receita Liquida") or 0) for r in dados_raw)
    # "Total Notas Fiscais" vem igual em todas as linhas (CROSS JOIN no SQL);
    # nao somar por marca, senao volta a contar a mesma NF mais de uma vez.
    total_qtd       = max((float(r.get("Total Notas Fiscais") or 0) for r in dados_raw), default=0)
    margem_geral    = (total_receita / total_anunciado * 100) if total_anunciado else 0

    def fmt_marca(r):
        return {
            "marca":      r.get("Marca") or "Sem marca",
            "margem":     _fmt_pct(float(r.get("Margem Pct") or 0)),
            "valor":      _fmt_moeda(float(r.get("Receita Liquida") or 0)),
            "anunciado":  _fmt_moeda(float(r.get("Vlr Anunciado") or 0)),
        }

    # esquerda: maior receita → menor
    marcas_desc  = [fmt_marca(r) for r in sorted(
        dados_raw, key=lambda r: float(r.get("Receita Liquida") or 0), reverse=True
    )]
    # direita: menor margem → maior
    marcas_cresc = [fmt_marca(r) for r in sorted(
        dados_raw, key=lambda r: float(r.get("Margem Pct") or 0)
    )]

    data_ini = filtros.get("data_ini", "")
    try:
        periodo = datetime.strptime(data_ini, "%Y-%m-%d").strftime("%d/%m/%Y")
    except Exception:
        periodo = data_ini

    cor_margem = "#16a34a" if margem_geral >= 0 else "#dc2626"

    return {
        "titulo":       relatorio.get("titulo", "Rentabilidade Ecommerce"),
        "periodo":      periodo,
        "data_geracao": datetime.now().strftime("%d/%m/%Y %H:%M"),
        "kpis": [
            {"label": "Margem do Dia",    "valor": _fmt_pct(margem_geral),       "cor": cor_margem},
            {"label": "Receita Líquida",  "valor": _fmt_moeda(total_receita),    "cor": "#0f172a"},
            {"label": "Valor Anunciado",  "valor": _fmt_moeda(total_anunciado),  "cor": "#0f172a"},
            {"label": "Total de Vendas",  "valor": _fmt_int(total_qtd),          "cor": "#0f172a"},
        ],
        "marcas_desc":  marcas_desc,
        "marcas_cresc": marcas_cresc,
    }
