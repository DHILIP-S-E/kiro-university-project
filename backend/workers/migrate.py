"""Lambda: run `alembic upgrade head`. Invoked by a CDK Trigger on every deploy."""

import os

from alembic import command
from alembic.config import Config

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def handler(_event, _context):
    cfg = Config(os.path.join(ROOT, "alembic.ini"))
    cfg.set_main_option("script_location", os.path.join(ROOT, "alembic"))
    command.upgrade(cfg, "head")
    return {"migrated": True}
