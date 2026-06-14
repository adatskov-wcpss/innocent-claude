#!/usr/bin/env python3
"""
Simple fetch proxy — GET /?url=https://example.com/file.jpg
Returns the fetched content with original Content-Type.
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import urllib.request

class ProxyHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # suppress logs

    def do_GET(self):
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)

        if 'url' not in params:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Missing ?url= param")
            return

        target = params['url'][0]

        try:
            req = urllib.request.Request(target, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=15) as resp:
                content_type = resp.headers.get('Content-Type', 'application/octet-stream')
                data = resp.read()

            self.send_response(200)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(data)

        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode())

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), ProxyHandler)
    print("Proxy running on :8080")
    server.serve_forever()
