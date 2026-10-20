"""Aplica as migrações pendentes do banco (Alembic), com backup automático antes.

    cd backend
    venv\\Scripts\\python migrar.py

Backup em BACKUP_DIR (.env; padrão ../_backups), mantendo os 2 últimos. Sem migração pendente, não faz nada.
"""
import os

import hlcore  # noqa: F401  (lê o .env)

os.environ.setdefault("DATABASE_URL", "sqlite:///./report.db")

from hlcore import migracoes  # noqa: E402

if __name__ == "__main__":
    aqui = os.path.dirname(os.path.abspath(__file__))
    pasta = os.getenv("BACKUP_DIR") or os.path.join(aqui, "..", "_backups")
    print(migracoes.atualizar(os.path.join(aqui, "alembic.ini"), pasta, "report"))
