"""Roda cada cenário de tests/cenarios/ isolado: processo próprio + banco NOVO migrado pelo Alembic (python migrar.py).

Os cenários sobem o app (TestClient) apontando para esse banco, montam os dados que precisam e conferem as regras
com chk(); terminam com "TODOS OS N TESTES PASSARAM". Integrações externas (SAP, Magis5) são simuladas.

    cd backend
    venv\\Scripts\\python -m pytest            (todos)
    venv\\Scripts\\python -m pytest -k reclass (só os que têm "reclass" no nome)
"""
import os
import subprocess
import sys
from pathlib import Path

import pytest

BACKEND = Path(__file__).resolve().parent.parent
CENARIOS = sorted((Path(__file__).parent / "cenarios").glob("cenario_*.py"))


def _rodar(args, banco, extra_env=None):
    env = {**os.environ, "PYTHONIOENCODING": "utf-8", "ALLOW_LOCAL_AUTH": "true",
           "DATABASE_URL": f"sqlite:///{banco.as_posix()}", **(extra_env or {})}
    return subprocess.run([sys.executable, *args], cwd=BACKEND, env=env, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=600)


@pytest.mark.parametrize("cenario", CENARIOS, ids=[c.stem.removeprefix("cenario_") for c in CENARIOS])
def test_cenario(cenario, tmp_path):
    banco = tmp_path / "teste.db"
    m = _rodar(["migrar.py"], banco, {"BACKUP_DIR": str(tmp_path / "backups")})
    assert m.returncode == 0, f"migração falhou:\n{m.stdout}{m.stderr}"
    r = _rodar([str(cenario), str(banco.as_posix())], banco)
    saida = r.stdout + r.stderr
    resumo = "\n".join(l for l in saida.splitlines() if "ok -" in l or "FALHOU" in l or "TODOS OS" in l or "Error" in l)
    assert r.returncode == 0 and "TODOS OS" in r.stdout, f"cenário {cenario.name} falhou:\n{resumo or saida[-3000:]}"
