"""Interactive, local-only configuration: python -m backend.configure.

Secrets never enter shell history, command arguments, or printed diagnostics.
The file uses JSON-quoted values and is read without executing shell syntax.
"""
from __future__ import annotations
import argparse
import getpass
import json
import os
from pathlib import Path
import secrets
from .providers import CompatibleProvider


def write_configuration(path: Path, values: dict[str, str]):
    # Never overwrite a deployment's working keys; exclusive creation also rejects symlinks.
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as stream:
        stream.write('# CareInOne server secrets. Do not commit or share this file.\n')
        for key, value in values.items():
            stream.write(key + '=' + json.dumps(value) + '\n')


def load_configuration(path: Path):
    values = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#'): continue
        key, separator, raw = line.partition('=')
        key = key.strip(); raw = raw.strip()
        if not separator or not key.startswith('CARE_') or not all(c.isupper() or c.isdigit() or c == '_' for c in key) or key in values:
            raise ValueError('Invalid or repeated configuration key')
        try: value = json.loads(raw) if raw.startswith('"') else raw
        except ValueError: raise ValueError('Invalid quoted configuration value') from None
        if not isinstance(value, str) or any(ord(c) < 32 for c in value): raise ValueError('Invalid configuration value')
        values[key] = value
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('.env'))
    args = parser.parse_args()
    print('Choose your server-side provider: openai, kimi, compatible, or mock.')
    provider = input('Provider: ').strip().lower()
    if provider not in {'openai', 'kimi', 'compatible', 'mock'}: raise ValueError('Unknown provider')
    values = {'CARE_PROVIDER': provider, 'CARE_BACKEND_TOKENS': secrets.token_urlsafe(32), 'CARE_MAX_SOURCE_CHARACTERS': '40000'}
    if provider == 'mock':
        values['CARE_ALLOW_MOCK'] = 'true'
    else:
        defaults = {'openai':'https://api.openai.com/v1', 'kimi':'https://api.moonshot.ai/v1'}
        base_url = defaults.get(provider) or input('Provider HTTPS base URL, including /v1: ').strip()
        model = input('Model ID available in your provider account: ').strip()
        key = getpass.getpass('Provider API key (hidden, stored only in the server file): ').strip()
        CompatibleProvider(base_url, key, model, adapter=provider)
        values.update(CARE_MODEL_BASE_URL=base_url, CARE_MODEL_NAME=model, CARE_MODEL_API_KEY=key, CARE_MODEL_MAX_OUTPUT_TOKENS='6000')
        if provider == 'kimi': values['CARE_MODEL_THINKING'] = 'disabled'
    write_configuration(args.output, values)
    print('Configuration created with owner-only permissions. No network request was made.')
    print('Start locally with: python -m backend.run')
    print('Deploy behind HTTPS, then enter your gateway URL and CARE_BACKEND_TOKENS value in the iPhone app. Never enter the provider API key there.')


if __name__ == '__main__':
    try: main()
    except (ValueError, OSError, RuntimeError): raise SystemExit('Setup did not finish. Check the inputs and choose an output file that does not already exist.') from None
