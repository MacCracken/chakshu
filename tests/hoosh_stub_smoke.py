#!/usr/bin/env python3
# hoosh-stub smoke — stand up a tiny OpenAI-shaped HTTP gateway, point
# `shu-ai --explain` at it, and assert it surfaces the answer. This is the
# design-spec §10 / roadmap "--explain returns something model-shaped" gate.
#
# Covers the hoosh HTTP client END-TO-END without a real gateway: sandhi
# POST → `/v1/chat/completions`, OpenAI-`content` extraction, and the
# bearer-token header (hoosh 2.3.5 auth). The streaming `?` overlay (SSE +
# incremental render) still needs a real TTY + hoosh to verify visually;
# the stub serves SSE for `"stream":true` so a future PTY smoke can use it.
#
# Usage: python3 tests/hoosh_stub_smoke.py [path/to/shu-ai]
import http.server, json, os, socket, subprocess, sys, threading

ANSWER = "stub says: this process looks idle"
seen = {"path": None, "auth": None, "stream": None, "model": None}


class Handler(http.server.BaseHTTPRequestHandler):
    # sandhi's HTTP client speaks 1.1; the BaseHTTPRequestHandler default
    # is 1.0, which sandhi's response parser rejects (reads as status 0 →
    # chakshu treats it as a transport failure). 1.1 needs Content-Length
    # on every response, which we set below.
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def do_POST(self):
        seen["path"] = self.path
        seen["auth"] = self.headers.get("Authorization")
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n).decode("utf-8", "replace")
        try:
            req = json.loads(body)
        except Exception:
            req = {}
        seen["stream"] = req.get("stream", False)
        seen["model"] = req.get("model")

        if self.path != "/v1/chat/completions":
            self.send_response(404)
            self.end_headers()
            return

        if seen["stream"]:
            # OpenAI SSE: a few content deltas, then the [DONE] sentinel.
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            for piece in ["stub ", "says ", "streamed"]:
                ev = json.dumps({"choices": [{"delta": {"content": piece}}]})
                self.wfile.write(f"data: {ev}\n\n".encode())
                self.wfile.flush()
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
        else:
            payload = json.dumps(
                {"choices": [{"message": {"content": ANSWER}}]}
            ).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def main():
    binary = sys.argv[1] if len(sys.argv) > 1 else "ai/build/shu-ai"
    port = free_port()
    # Threading server so HTTP/1.1 keep-alive connections don't block.
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()

    url = f"http://127.0.0.1:{port}/v1/chat/completions"
    env = dict(
        os.environ,
        CHAKSHU_HOOSH_URL=url,
        CHAKSHU_HOOSH_TOKEN="smoke-tok",
        CHAKSHU_MODEL="stub-model",
    )
    try:
        # pid 1 always exists; --explain is the non-interactive one-shot.
        out = subprocess.run(
            [binary, "--explain", "1"],
            capture_output=True, text=True, env=env, timeout=30,
        )
    finally:
        srv.shutdown()

    fails = []
    if ANSWER not in out.stdout:
        fails.append(f"answer not surfaced on stdout\n    stdout={out.stdout!r}\n    stderr={out.stderr!r}")
    if seen["path"] != "/v1/chat/completions":
        fails.append(f"gateway hit wrong path: {seen['path']!r}")
    if seen["auth"] != "Bearer smoke-tok":
        fails.append(f"bearer token not sent (got {seen['auth']!r})")
    if seen["model"] != "stub-model":
        fails.append(f"model not threaded through (got {seen['model']!r})")

    if fails:
        print(f"hoosh-stub smoke: FAIL ({binary})")
        for f in fails:
            print(f"  - {f}")
        sys.exit(1)
    print(f"hoosh-stub smoke: PASS ({binary}) — answer surfaced; Bearer + model + path verified")


if __name__ == "__main__":
    main()
