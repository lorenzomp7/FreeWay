"""Adattatore per evitare i modelli sperimentali hardcoded nell'upstream."""
import os
import sys

if not os.getenv('GOOGLE_API_KEY'):
    sys.exit('GOOGLE_API_KEY mancante')

from vibetest import agents
from vibetest.mcp_server import run

_upstream_chat = agents.ChatGoogle


def configured_chat(**kwargs):
    kwargs['model'] = os.getenv('FREEWAY_QA_MODEL', 'gemini-2.5-flash')
    return _upstream_chat(**kwargs)


agents.ChatGoogle = configured_chat

if __name__ == '__main__':
    run()
