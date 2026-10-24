"""Boot the actual production image with mock-only ephemeral configuration."""
import argparse
import json
import secrets
import subprocess
import sys
from http_smoke import free_port, mock_environment, verify_http

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('image',nargs='?',default='careinone-web:test')
    parser.add_argument('--local-only',action='store_true')
    args=parser.parse_args(); image=args.image
    port = free_port()
    origin = f'http://127.0.0.1:{port}'
    env, token, code = mock_environment(origin)
    if args.local_only:
        env['CARE_WEB_CLOUD_ENABLED']='false'
        env.pop('CARE_WEB_SESSION_SECRET');env.pop('CARE_WEB_ACCESS_CODES')
    name = 'careinone-web-smoke-' + secrets.token_hex(6)
    command = ['docker', 'run', '--rm', '-d', '--name', name, '--read-only', '--cap-drop=ALL',
               '--security-opt=no-new-privileges', '--tmpfs', '/tmp:rw,noexec,nosuid,size=16m',
               '-p', f'127.0.0.1:{port}:10000']
    for key in sorted(k for k in env if k.startswith('CARE_')):
        command.extend(['-e', key])  # Values come from subprocess environment, never argv.
    command.append(image)
    try:
        subprocess.run(command, env=env, check=True, capture_output=True)
        report = verify_http(origin, token, code, transport='production Docker image over localhost HTTP',cloud=not args.local_only)
        uid = subprocess.check_output(['docker', 'exec', name, 'id', '-u'], text=True).strip()
        assert uid == '10001'
        report.update(nonRootUID=uid, readOnlyContainer=True)
        print(json.dumps(report, indent=2))
    finally:
        subprocess.run(['docker', 'rm', '-f', name], capture_output=True)

if __name__ == '__main__':
    main()
