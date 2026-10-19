# -*- coding: utf-8 -*-
"""本地测试线程版网页构建用的 HTTP 服务器（带跨域隔离头）。

线程版（variant/thread_support=true）依赖 SharedArrayBuffer，浏览器要求
COOP/COEP 头才会启用，python -m http.server 不带这些头会让游戏直接起不来。
用法：

    py -3 tools/serve_web.py [端口]     # 默认 8642，服务 export/web/

注意：这只是本地自测用；itch 托管自带这些头，上传 zip 即可。
"""
import functools
import http.server
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "export" / "web"

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        self.send_header("Cache-Control", "no-cache, must-revalidate")
        super().end_headers()

    def log_message(self, fmt, *args):
        pass  # 安静模式

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8642
    handler = functools.partial(Handler, directory=str(ROOT))
    print(f"serving {ROOT} at http://127.0.0.1:{port}/ (COOP/COEP on)")
    http.server.ThreadingHTTPServer(("127.0.0.1", port), handler).serve_forever()
