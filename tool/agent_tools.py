#!/usr/bin/env python3
"""Installazioni locali ripetibili; nessuna chiave viene salvata su disco."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.agent-tools'
SOURCES = json.loads((ROOT / 'tools/agents/sources.json').read_text())


def run(*args, cwd=ROOT):
    subprocess.run([str(arg) for arg in args], cwd=cwd, check=True)


def checkout(name):
    spec = SOURCES[name]
    dest = CACHE / name
    if not dest.exists():
        run('git', 'clone', '--no-checkout', spec['url'], dest)
    run('git', 'fetch', 'origin', spec['ref'], cwd=dest)
    run('git', 'checkout', '--detach', 'FETCH_HEAD', cwd=dest)
    return dest


def python_bin():
    return CACHE / 'vibetest-venv' / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')


def setup(component):
    CACHE.mkdir(exist_ok=True)
    if component in ('all', 'node'):
        run('npm', 'ci', cwd=ROOT / 'tools/agents')
        if not os.getenv('FREEWAY_CHROMIUM_PATH'):
            run('npx', '--no-install', 'playwright', 'install', 'chromium', cwd=ROOT / 'tools/agents')
    if component in ('all', 'skills'):
        source = checkout('agent-skills')
        for host in ('.agents', '.claude'):
            target = ROOT / host / 'skills'
            target.mkdir(parents=True, exist_ok=True)
            for skill in (source / 'skills').iterdir():
                if skill.is_dir():
                    dest = target / skill.name
                    # Do not overwrite user-maintained skills.
                    if dest.exists() and not dest.is_symlink():
                        raise SystemExit(f'Skill già presente: {dest}')
                    if dest.is_symlink():
                        dest.unlink()
                    dest.symlink_to(skill, target_is_directory=True)
        print('Skill upstream installate per Codex e Claude Code; riavviare la sessione.')
    if component in ('all', 'vibetest'):
        source = checkout('vibetest-use')
        if not python_bin().exists():
            run(sys.executable, '-m', 'venv', CACHE / 'vibetest-venv')
        run(python_bin(), '-m', 'pip', 'install', '-c', ROOT / 'tools/agents/vibetest-constraints.txt', '-e', source)
        if not os.getenv('FREEWAY_CHROMIUM_PATH'):
            run(python_bin(), '-m', 'playwright', 'install', 'chromium')
    if component == 'syncfusion':
        source = checkout('syncfusion-examples')
        print(f'Esempi disponibili in {source}; leggere LICENSE prima di riutilizzare widget.')
    if component == 'container':
        if not shutil.which('go'):
            raise SystemExit('Serve Go per installare Container Use; alternativa: brew install dagger/tap/container-use')
        version = subprocess.run(['go', 'version'], capture_output=True, text=True)
        if version.returncode or 'go version go' not in version.stdout:
            raise SystemExit('Il comando go trovato non è il compilatore Go; installare Go da go.dev.')
        run('go', 'install', 'github.com/dagger/container-use/cmd/container-use@' + SOURCES['container-use']['ref'])
        print('Aggiungere $(go env GOPATH)/bin al PATH; serve anche Docker attivo.')


def doctor():
    checks = {
        'Flutter': shutil.which('flutter') is not None,
        'Node': shutil.which('node') is not None,
        'strumenti Node': (ROOT / 'tools/agents/node_modules/.bin/playwriter').exists(),
        'skill Codex': (ROOT / '.agents/skills/code-review-and-quality/SKILL.md').exists(),
        'Vibetest installato': python_bin().exists(),
        'chiave per QA AI': bool(os.getenv('GOOGLE_API_KEY')),
        'Container Use': shutil.which('container-use') is not None,
        'Docker': shutil.which('docker') is not None,
    }
    for name, ok in checks.items():
        print(f'{"OK" if ok else "MANCANTE"}: {name}')
    print('Playwriter richiede inoltre Chrome con estensione collegata; Gemini richiede login.')
    return 0 if all(checks.values()) else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    install = sub.add_parser('setup')
    install.add_argument('component', choices=['all', 'node', 'skills', 'vibetest', 'container', 'syncfusion'])
    sub.add_parser('doctor')
    sub.add_parser('vibetest')
    sub.add_parser('serve')
    args = parser.parse_args()
    if args.action == 'setup':
        setup(args.component)
    elif args.action == 'doctor':
        return doctor()
    elif args.action == 'vibetest':
        if not os.getenv('GOOGLE_API_KEY'):
            raise SystemExit('Esportare GOOGLE_API_KEY prima di avviare Vibetest.')
        if not python_bin().exists():
            raise SystemExit('Eseguire prima: python3 tool/agent_tools.py setup vibetest')
        os.execv(str(python_bin()), [str(python_bin()), str(ROOT / 'tools/agents/vibetest_server.py')])
    elif args.action == 'serve':
        run('flutter', 'build', 'web', '--release', '--pwa-strategy=none', '--base-href', '/')
        run(sys.executable, '-m', 'http.server', '8080', '--bind', '127.0.0.1', '--directory', ROOT / 'build/web')
    return 0


if __name__ == '__main__':
    sys.exit(main())
