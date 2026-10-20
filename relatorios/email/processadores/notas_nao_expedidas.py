from datetime import datetime


def _fmt_int(v):
    return f"{int(v or 0):,}".replace(",", ".")


def preparar_contexto(dados_raw, relatorio, filtros):
    total_geral  = sum(int(r.get("Total Notas Nao Expedidas") or 0) for r in dados_raw)
    dias_parados = len(dados_raw)

    dados = [
        {
            "data":  r.get("Data"),
            "total": _fmt_int(r.get("Total Notas Nao Expedidas")),
        }
        for r in dados_raw
    ]

    colunas = [
        {"label": "Data",            "campo": "data"},
        {"label": "Total de Notas",  "campo": "total", "alinhar_direita": True, "negrito": True},
    ]

    return {
        "titulo":           relatorio.get("titulo", "Notas não expedidas"),
        "periodo":          f"{dias_parados} data(s) com pendência" if dias_parados else "Nenhuma pendência",
        "data_geracao":     datetime.now().strftime("%d/%m/%Y %H:%M"),
        "subtitulo_tabela": "Resumo por Data",
        "kpis": [
            {"label": "Total de Notas Não Expedidas", "valor": _fmt_int(total_geral),  "cor": "#dc2626" if total_geral else "#16a34a"},
            {"label": "Datas com Pendência",          "valor": _fmt_int(dias_parados), "cor": "#0f172a"},
        ],
        "colunas": colunas,
        "dados":   dados,
    }
