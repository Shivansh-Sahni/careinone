"""Start the gateway with a local .env; no shell evaluation or access logs."""
import argparse
import os
from pathlib import Path
from .configure import load_configuration


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env-file', type=Path, default=Path('.env'))
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=8000)
    args = parser.parse_args()
    try:
        for key, value in load_configuration(args.env_file).items(): os.environ.setdefault(key, value)
        from .app import create_app
        app = create_app()
    except (ValueError, OSError, RuntimeError): raise SystemExit('Gateway configuration is invalid. Run python -m backend.configure or check your server environment.') from None
    import uvicorn
    uvicorn.run(app, host=args.host, port=args.port, access_log=False, log_level='warning', proxy_headers=False)


if __name__ == '__main__': main()
