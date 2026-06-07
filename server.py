#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
婚姻占卜术·掌中诀 - 轻量级 HTTP 静态服务
- 仅依赖 Python 标准库（http.server）
- 默认绑定 0.0.0.0:8080
- 支持通过环境变量 PORT 覆盖端口
- 自带简单访问日志
"""

import os
import sys
import socket
from http.server import HTTPServer, SimpleHTTPRequestHandler
from functools import partial


class DivinationHandler(SimpleHTTPRequestHandler):
    """定制 handler：添加访问日志 + 正确中文响应头"""

    def end_headers(self):
        # 禁止缓存，方便即时看到修改
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, fmt, *args):
        # 简化日志格式：时间 - 客户端 - 状态
        try:
            client = self.client_address[0]
        except Exception:
            client = "?"
        sys.stdout.write(f"[{self.log_date_time_string()}] {client} - {fmt % args}\n")
        sys.stdout.flush()


def get_local_ip() -> str:
    """获取本机局域网 IP（用于提示，非公网）"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def main():
    port = int(os.environ.get("PORT", "8080"))
    host = os.environ.get("HOST", "0.0.0.0")

    # 切换到脚本所在目录作为根目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)

    handler = partial(DivinationHandler, directory=script_dir)
    httpd = HTTPServer((host, port), handler)

    banner = f"""
╔════════════════════════════════════════════════════════╗
║   🪄  婚姻占卜术·掌中诀  HTTP 服务已启动                ║
╠════════════════════════════════════════════════════════╣
║   监听地址 : http://{host}:{port}
║   服务目录 : {script_dir}
║   本机内网 : http://{get_local_ip()}:{port}
║   按 Ctrl+C 停止服务
╚════════════════════════════════════════════════════════╝
"""
    print(banner)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[INFO] 服务已停止")
        httpd.server_close()


if __name__ == "__main__":
    main()
