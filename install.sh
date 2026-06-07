#!/usr/bin/env bash
# 婚姻占卜术 · 掌中诀 - 一键部署脚本
# 适用：Linux / macOS（Windows 需用 install.ps1 或 WSL）

set -e
BOLD="\033[1m"; GREEN="\033[0;32m"; YELLOW="\033[0;33m"; NC="\033[0m"
echo -e "${BOLD}🪄 婚姻占卜术·掌中诀  部署向导${NC}"
echo "============================================"

# ---------- 1. 检测 Python ----------
echo -e "\n[1/5] 检查 Python..."
if command -v python3 &>/dev/null; then
    PY=python3
elif command -v python &>/dev/null; then
    PY=python
else
    echo -e "${YELLOW}❌ 未检测到 Python，请先安装 Python 3.8+${NC}"
    echo "   macOS: brew install python3"
    echo "   Ubuntu/Debian: sudo apt install python3"
    echo "   Windows: https://www.python.org/downloads/"
    exit 1
fi
$PY --version
echo -e "${GREEN}✅ Python OK${NC}"

# ---------- 2. 安装 cloudflared ----------
echo -e "\n[2/5] 安装 cloudflared..."

if command -v cloudflared &>/dev/null; then
    echo "✅ cloudflared 已安装: $(cloudflared --version 2>&1 | head -1)"
else
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"
    case "$OS-$ARCH" in
        linux-x86_64)   CF_ARCH=amd64 ;;
        linux-aarch64)  CF_ARCH=arm64 ;;
        darwin-x86_64)  CF_ARCH=amd64 ;;
        darwin-arm64)   CF_ARCH=arm64 ;;
        *) echo "❌ 不支持的平台 $OS-$ARCH，请手动安装: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"; exit 1 ;;
    esac
    CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${OS}-${CF_ARCH}"
    if [ "$OS" = "linux" ]; then
        CF_URL="${CF_URL}.deb"
    fi
    echo "⬇️  下载: $CF_URL"
    TMP=$(mktemp -d)
    cd "$TMP"
    curl -fsSL -o cloudflared "$CF_URL"
    if [ "$OS" = "linux" ]; then
        if command -v sudo &>/dev/null; then SUDO=sudo; else SUDO=""; fi
        $SUDO dpkg -i cloudflared || $SUDO apt-get install -f -y
    else
        mkdir -p ~/bin
        mv cloudflared ~/bin/cloudflared
        chmod +x ~/bin/cloudflared
        echo "export PATH=\$HOME/bin:\$PATH" >> ~/.zshrc 2>/dev/null || true
        echo "export PATH=\$HOME/bin:\$PATH" >> ~/.bashrc 2>/dev/null || true
    fi
    cd - >/dev/null
    echo -e "${GREEN}✅ cloudflared 安装完成${NC}"
fi

# ---------- 3. 询问隧道名 + 域名 ----------
echo -e "\n[3/5] 配置隧道"
echo "   请准备好您在 Cloudflare 授权的域名"
echo ""
TUNNEL_NAME=${TUNNEL_NAME:-divination-tunnel}
SUBDOMAIN=${SUBDOMAIN:-divination}
if [ -z "$DOMAIN" ]; then
  echo -e "${YELLOW}❌ 请设置环境变量 DOMAIN=<您的域名> 后再跑${NC}"
  echo "   示例: export DOMAIN=example.com"
  exit 1
fi
FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"
echo "   隧道名: $TUNNEL_NAME"
echo "   外网域名: https://${FULL_DOMAIN}"
echo ""

# ---------- 4. 登录 + 创建隧道（仅首次） ----------
echo -e "\n[4/5] 登录 Cloudflare（仅首次需要）"
if [ ! -f "$HOME/.cloudflared/cert.pem" ]; then
    echo "⚠️  即将打开浏览器授权页面..."
    echo "    若无图形界面，请复制输出的 URL 到手机/电脑浏览器打开"
    cloudflared tunnel login
    echo -e "${GREEN}✅ 登录完成${NC}"
else
    echo "✅ 已检测到证书，跳过登录"
fi

echo "   创建命名隧道: $TUNNEL_NAME"
if ! cloudflared tunnel info "$TUNNEL_NAME" &>/dev/null; then
    cloudflared tunnel create "$TUNNEL_NAME"
fi
TUNNEL_ID=$(cloudflared tunnel info "$TUNNEL_NAME" | grep -oE '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' | head -1)
echo "   隧道ID: $TUNNEL_ID"

# 创建 DNS 记录（幂等）
echo "   配置 DNS: ${FULL_DOMAIN} -> 隧道"
cloudflared tunnel route dns "$TUNNEL_NAME" "$FULL_DOMAIN" || echo "   (DNS 记录可能已存在)"

# 写配置文件
mkdir -p ~/.cloudflared
cat > ~/.cloudflared/config.yml <<EOF
tunnel: $TUNNEL_NAME
credentials-file: $HOME/.cloudflared/${TUNNEL_ID}.json

ingress:
  - hostname: ${FULL_DOMAIN}
    service: http://localhost:8080
  - service: http_status:404
EOF
echo -e "${GREEN}✅ 隧道配置完成${NC}"

# ---------- 5. 启动服务 ----------
echo -e "\n[5/5] 启动服务"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 启动 HTTP 服务（后台）
echo "   启动 HTTP 服务..."
nohup $PY "$SCRIPT_DIR/server.py" > "$SCRIPT_DIR/server.log" 2>&1 &
HTTP_PID=$!
echo "   HTTP PID: $HTTP_PID"
sleep 2

# 启动隧道（后台）
echo "   启动 Cloudflare 隧道..."
nohup cloudflared tunnel run "$TUNNEL_NAME" > "$SCRIPT_DIR/tunnel.log" 2>&1 &
CF_PID=$!
echo "   Tunnel PID: $CF_PID"

# systemd 服务（Linux）
if command -v systemctl &>/dev/null; then
    echo "   注册 systemd 自启服务..."
    SERVICE_FILE="$HOME/.config/systemd/user/cloudflared-divination.service"
    mkdir -p "$(dirname "$SERVICE_FILE")"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Divination HTTP + Cloudflare Tunnel
After=network.target

[Service]
Type=simple
WorkingDirectory=$SCRIPT_DIR
ExecStart=$PY $SCRIPT_DIR/server.py
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload 2>/dev/null
    systemctl --user enable cloudflared-divination.service 2>/dev/null
    echo "   ✅ 已配置用户级 systemd（执行 'systemctl --user start cloudflared-divination' 启动）"
fi

sleep 3
echo ""
echo -e "${BOLD}============================================${NC}"
echo -e "${GREEN}🎉 部署完成！${NC}"
echo -e "${BOLD}外网地址: https://${FULL_DOMAIN}${NC}"
echo "============================================"
echo ""
echo "📋 常用命令:"
echo "  查看 HTTP 日志: tail -f $SCRIPT_DIR/server.log"
echo "  查看隧道日志: tail -f $SCRIPT_DIR/tunnel.log"
echo "  停止服务:      kill $HTTP_PID $CF_PID"
echo "  开机自启:      systemctl --user enable --now cloudflared-divination"
