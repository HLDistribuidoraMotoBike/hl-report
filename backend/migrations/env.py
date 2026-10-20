"""Ambiente do Alembic: usa a mesma conexão do app (hlcore.database, DATABASE_URL do .env) e o metadata de
TODOS os modelos (tabelas comuns do hl-core + as dos módulos). render_as_batch: o SQLite não altera coluna/
constraint com ALTER TABLE — o Alembic recria a tabela."""
import os

import hlcore  # noqa: F401  (lê o .env)

os.environ.setdefault("DATABASE_URL", "sqlite:///./report.db")

from alembic import context  # noqa: E402

from hlcore.database import Base, engine  # noqa: E402
import hlcore.modelos  # noqa: E402,F401  (tabelas comuns)
import app.modulos.email.models  # noqa: E402,F401

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(url=str(engine.url), target_metadata=target_metadata, literal_binds=True,
                      render_as_batch=True)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata, render_as_batch=True)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
