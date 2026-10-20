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


def _nome_canal(r):
    canal = r.get("Canal") or "Sem canal"
    setor = r.get("Setor")
    return f"{canal} - {setor}" if setor else canal


def _fmt_linha(r, identificador=None):
    linha = {
        "margem":          _fmt_pct(float(r.get("Margem Pct") or 0)),
        "receita_liquida": _fmt_moeda(float(r.get("Receita Liquida") or 0)),
        "total_vendas":    _fmt_int(r.get("Vendas")),
        "total_receita":   _fmt_moeda(float(r.get("Total Receita") or 0)),
        "total_despesa":   _fmt_moeda(float(r.get("Total Despesa") or 0)),
        "total_custo":     _fmt_moeda(float(r.get("Total Custo Merc.") or 0)),
    }
    linha["nome"] = identificador if identificador is not None else _nome_canal(r)
    return linha


def _rank_por_canal(dados_raw, grupo, top5_receita_no_melhor=False):
    """Agrupa as linhas de um bloco (Venda/Marca/Vendedor) por Canal/Setor e
    devolve, para cada Canal/Setor, o Top 5 melhor e o Top 5 pior margem.

    Se top5_receita_no_melhor=True, o Top 5 Melhor Margem passa a considerar
    apenas as 5 linhas de maior Receita (evita destacar marcas com margem
    boa mas receita insignificante); o Top 5 Pior Margem nao muda.
    """
    por_canal = {}
    for r in dados_raw:
        if r.get("Grupo") != grupo:
            continue
        por_canal.setdefault(_nome_canal(r), []).append(r)

    resultado = []
    for nome_canal, linhas in por_canal.items():
        if top5_receita_no_melhor:
            top_receita  = sorted(linhas, key=lambda r: float(r.get("Total Receita") or 0), reverse=True)[:5]
            melhores_raw = sorted(top_receita, key=lambda r: float(r.get("Margem Pct") or 0), reverse=True)
        else:
            melhores_raw = sorted(linhas, key=lambda r: float(r.get("Margem Pct") or 0), reverse=True)[:5]

        piores_raw = sorted(linhas, key=lambda r: float(r.get("Margem Pct") or 0))[:5]

        resultado.append({
            "nome":     nome_canal,
            "melhores": [_fmt_linha(r, r.get("Identificador")) for r in melhores_raw],
            "piores":   [_fmt_linha(r, r.get("Identificador")) for r in piores_raw],
        })
    return resultado


def preparar_contexto(dados_raw, relatorio, filtros):
    dados_canal = [r for r in dados_raw if r.get("Grupo") == "Canal"]

    canais = [_fmt_linha(r) for r in dados_canal]

    total_receita_liq = sum(float(r.get("Receita Liquida") or 0) for r in dados_canal)
    total_vlr          = sum(float(r.get("Vlr Total") or 0) for r in dados_canal)
    total_vendas        = sum(int(r.get("Vendas") or 0) for r in dados_canal)
    total_receita_col   = sum(float(r.get("Total Receita") or 0) for r in dados_canal)
    total_despesa_col   = sum(float(r.get("Total Despesa") or 0) for r in dados_canal)
    total_custo_col     = sum(float(r.get("Total Custo Merc.") or 0) for r in dados_canal)
    margem_geral        = (total_receita_liq / total_vlr * 100) if total_vlr else 0

    canal_total = {
        "nome":            "Total Geral",
        "margem":          _fmt_pct(margem_geral),
        "receita_liquida": _fmt_moeda(total_receita_liq),
        "total_vendas":    _fmt_int(total_vendas),
        "total_receita":   _fmt_moeda(total_receita_col),
        "total_despesa":   _fmt_moeda(total_despesa_col),
        "total_custo":     _fmt_moeda(total_custo_col),
    }

    credito_pirelli   = sum(float(r.get("Credito Pirelli") or 0) for r in dados_canal)
    credito_presumido = sum(float(r.get("Credito Presumido") or 0) for r in dados_canal)

    detalhes = [
        {"titulo": "Por Venda (NF)", "coluna_id": "NF",       "canais": _rank_por_canal(dados_raw, "Venda")},
        {"titulo": "Por Marca",      "coluna_id": "Marca",    "canais": _rank_por_canal(dados_raw, "Marca", top5_receita_no_melhor=True)},
        {"titulo": "Por Vendedor",   "coluna_id": "Vendedor", "canais": _rank_por_canal(dados_raw, "Vendedor")},
    ]

    data_ini = filtros.get("data_ini", "")
    try:
        data_base = datetime.strptime(data_ini, "%Y-%m-%d").strftime("%d/%m/%Y")
    except Exception:
        data_base = data_ini

    return {
        "titulo":            relatorio.get("titulo", "Rentabilidade Consolidada"),
        "data_base":         data_base,
        "data_geracao":      datetime.now().strftime("%d/%m/%Y %H:%M"),
        "canais":            canais,
        "canal_total":       canal_total,
        "credito_pirelli":   _fmt_moeda(credito_pirelli),
        "credito_presumido": _fmt_moeda(credito_presumido),
        "detalhes":          detalhes,
    }
