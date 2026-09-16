"""Serves mobile/build/web over HTTPS using the self-signed dev cert in
.certs/, so browsers treat it as a secure context - required for real
native file-sharing (navigator.share with files) to work, e.g. sharing a
receipt PDF straight into WhatsApp. See mobile/lib/config/api_config.dart
for why the backend needs to match over HTTPS too.
"""

import http.server
import ssl
from pathlib import Path

ROOT = Path(__file__).parent / "mobile" / "build" / "web"
CERT_DIR = Path(__file__).parent / ".certs"
PORT = 5000


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def run() -> None:
    server = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(certfile=str(CERT_DIR / "devcert.pem"), keyfile=str(CERT_DIR / "devkey.pem"))
    server.socket = ctx.wrap_socket(server.socket, server_side=True)
    print(f"Serving {ROOT} over HTTPS on 0.0.0.0:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    run()
