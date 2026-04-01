#!/usr/bin/env python3
"""Development server with Cross-Origin Isolation headers for SharedArrayBuffer support."""
# SPDX-FileCopyrightText: 2026 Blender Web Authors
# SPDX-License-Identifier: GPL-2.0-or-later

import http.server
import sys
import os
import mimetypes


class COIHandler(http.server.SimpleHTTPRequestHandler):
    """Handler that adds COOP/COEP headers and correct WASM MIME type."""

    def end_headers(self):
        # Cross-Origin Isolation headers (required for SharedArrayBuffer / pthreads)
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        # Cache control for development
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()

    def guess_type(self, path):
        """Ensure correct MIME types for WASM and compressed WASM files."""
        if path.endswith(".wasm"):
            return "application/wasm"
        if path.endswith(".wasm.br"):
            return "application/wasm"
        if path.endswith(".wasm.gz"):
            return "application/wasm"
        return super().guess_type(path)

    def do_GET(self):
        """Handle GET requests with Content-Encoding for compressed WASM."""
        if self.path.endswith(".wasm.br"):
            self.send_response(200)
            self.send_header("Content-Type", "application/wasm")
            self.send_header("Content-Encoding", "br")
            self.end_headers()
            file_path = self.translate_path(self.path)
            try:
                with open(file_path, "rb") as f:
                    self.wfile.write(f.read())
            except FileNotFoundError:
                self.send_error(404, "File not found")
            return
        if self.path.endswith(".wasm.gz"):
            self.send_response(200)
            self.send_header("Content-Type", "application/wasm")
            self.send_header("Content-Encoding", "gzip")
            self.end_headers()
            file_path = self.translate_path(self.path)
            try:
                with open(file_path, "rb") as f:
                    self.wfile.write(f.read())
            except FileNotFoundError:
                self.send_error(404, "File not found")
            return
        super().do_GET()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    directory = sys.argv[2] if len(sys.argv) > 2 else "."
    os.chdir(directory)
    server = http.server.HTTPServer(("", port), COIHandler)
    print(f"Serving on http://localhost:{port} with Cross-Origin Isolation")
    print(f"  Cross-Origin-Opener-Policy: same-origin")
    print(f"  Cross-Origin-Embedder-Policy: require-corp")
    print(f"  Root directory: {os.getcwd()}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
        server.server_close()
