"""Run the independent signing service. Environment is supplied by systemd."""
import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import signal
import threading

from http_server import make_server
from oss_signer import signer_from_env
from service import Service, Settings


def main():
    os.umask(0o077)
    logger = logging.getLogger('pvp')
    logger.setLevel(logging.INFO)
    log_path = os.environ.get('PVP_LOG_FILE', '')
    handler = RotatingFileHandler(log_path, maxBytes=2 * 1024 * 1024, backupCount=3) if log_path else logging.StreamHandler()
    handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s %(message)s'))
    logger.addHandler(handler)
    # Prevent vendor debug logging from including request signatures or credentials.
    for name in ('oss2', 'aliyunsdkcore', 'urllib3'):
        vendor = logging.getLogger(name)
        vendor.handlers = [logging.NullHandler()]
        vendor.propagate = False
        vendor.setLevel(logging.CRITICAL + 1)
    settings = Settings(
        pool_ids=tuple(p.strip() for p in os.environ.get('PVP_POOL_IDS', '').split(',') if p.strip()),
        identity_hour_limit=int(os.environ.get('PVP_IDENTITY_HOUR_LIMIT', '600')),
        ip_hour_limit=int(os.environ.get('PVP_IP_HOUR_LIMIT', '1800')),
        session_hour_limit=int(os.environ.get('PVP_SESSION_HOUR_LIMIT', '30')),
        token_ttl=int(os.environ.get('PVP_TOKEN_TTL', str(30 * 86400))),
        device_token_ttl=int(os.environ.get('PVP_DEVICE_TOKEN_TTL', '86400')),
        device_hour_limit=int(os.environ.get('PVP_DEVICE_HOUR_LIMIT', '30')),
    )
    try:
        signer = signer_from_env(os.environ)
    except (ImportError, ValueError):
        signer = None
        logger.error('storage_configuration_unavailable')
    database = Path(os.environ.get('PVP_DATABASE', '/var/lib/pvp-signer/state.db'))
    service = Service(database, settings, signer)
    server = make_server(service, ('127.0.0.1', int(os.environ.get('PVP_PORT', '8430'))),
                         trust_proxy=os.environ.get('PVP_TRUST_PROXY') == '1',
                         cors_origins=tuple(origin.strip() for origin in os.environ.get('PVP_CORS_ORIGINS', '').split(',') if origin.strip()))
    def stop(signum, frame):
        threading.Thread(target=server.shutdown, daemon=True).start()
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    logger.info('service_started storage=%s', 'configured' if signer else 'unconfigured')
    try:
        server.serve_forever(poll_interval=.2)
    finally:
        # Stop accepting, then drain non-daemon workers before closing SQLite.
        # Socket idle timeout is 10s; systemd supplies the 15s hard stop bound.
        server.server_close()
        service.close()

if __name__ == '__main__': main()
