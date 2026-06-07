# 🪄 divination-bundle · 民间偏方 + 婚姻占卜

> 一个零依赖的静态网页套装：民间偏方（34 个）+ 婚姻占卜（掌中诀合婚）+ 轻量级 HTTP 服务 + Cloudflare Tunnel 一键部署脚本。

## ✨ 特性

- 📜 **完全静态**：HTML + CSS + 原生 JS，无构建步骤、无 npm
- 🐍 **零依赖服务**：纯 Python 标准库 `http.server`，几十行代码
- 🌐 **一键公网**：配合 `cloudflared` 隧道，5 分钟暴露到公网
- 📱 **移动端友好**：响应式断点 + 精准锚点定位（hash 跳转）
- 🔍 **双索引**：按分类 / 按病种 双向索引
- 🎨 **传统中国风**：绛红 + 哑金 + 宣纸背景

## 📂 文件清单

| 文件 | 说明 |
|------|------|
| `index.html` | 首页：入口卡 + 偏方浏览器（搜索框 + 分类/病种过滤 + 动态列表）|
| `pianfang.html` | 偏方详情页：单卡片展示（上一条/下一条/返回首页导航）|
| `pianfang-data.js` | 偏方数据源（index 和 pianfang 共用）|
| `new.html` | 婚姻占卜：掌中诀合婚引擎（输入生日 → 算年柱/月柱/日柱）|
| `server.py` | Python HTTP 服务（标准库，零依赖）|
| `config.yml` | Cloudflare 隧道配置模板（运行时由 install.sh 生成实际配置）|
| `install.sh` | Linux / macOS 一键部署脚本 |
| `install.ps1` | Windows PowerShell 一键部署脚本 |
| `README.md` | 本文档 |

## 🚀 5 分钟跑起来

### 方式 A：纯本地（无公网）

```bash
python3 server.py
# 浏览器打开 http://127.0.0.1:8080
```

### 方式 B：公网部署（Cloudflare Tunnel）

#### Linux / macOS

```bash
# 1. 准备一个你自己的、已经接入 Cloudflare 的域名
# 2. 设置环境变量
export DOMAIN=your-domain.com
export SUBDOMAIN=divination
export TUNNEL_NAME=divination-tunnel

# 3. 跑安装脚本
chmod +x install.sh
./install.sh
```

#### Windows（PowerShell 管理员）

```powershell
$env:DOMAIN = "your-domain.com"
$env:SUBDOMAIN = "divination"
$env:TUNNEL_NAME = "divination-tunnel"

powershell -ExecutionPolicy Bypass -File install.ps1
```

脚本会自动：

1. ✅ 检测/安装 Python 3
2. ✅ 检测/安装 cloudflared
3. ✅ `cloudflared tunnel login`（**首次需要在浏览器点 Allow**）
4. ✅ 创建命名隧道（已存在则跳过）
5. ✅ 在 Cloudflare 后台加 DNS 记录：`divination.your-domain.com → 隧道`
6. ✅ 写入 `~/.cloudflared/config.yml`
7. ✅ 后台启动 HTTP 服务（端口 8080）
8. ✅ 后台启动 Cloudflare 隧道
9. ✅ Linux 自动注册 systemd 用户级服务（开机自启）

## ✅ 验证

跑完脚本，浏览器打开：

```
https://divination.your-domain.com
```

看到首页 = 部署成功。

## 🛠 常用命令

```bash
# 查看 HTTP 日志
tail -f server.log

# 查看隧道日志
tail -f tunnel.log

# 重启服务
pkill -f "server.py"
pkill -f "cloudflared tunnel"
nohup python3 server.py > server.log 2>&1 &
nohup cloudflared tunnel run $TUNNEL_NAME > tunnel.log 2>&1 &

# Linux 开机自启（脚本已自动配置）
systemctl --user enable --now cloudflared-divination
```

## 🗑 卸载

```bash
# 1. 停止进程
pkill -f "server.py"
pkill -f "cloudflared tunnel"

# 2. 删除隧道（可选，Cloudflare 控制台也行）
cloudflared tunnel delete divination-tunnel

# 3. 删除 DNS 记录（Cloudflare 控制台操作）

# 4. 删 systemd 服务
systemctl --user disable --now cloudflared-divination
rm ~/.config/systemd/user/cloudflared-divination.service
```

## 🔧 故障排查

| 现象 | 排查 |
|------|------|
| 浏览器打不开域名 | `cat tunnel.log` 看是否有 `Registered tunnel connection` |
| 530 错误 | 隧道还在握手，等 1-2 分钟 |
| 502 错误 | HTTP 服务没起，`curl http://127.0.0.1:8080` 验证 |
| cloudflared login 报"无 cert" | 重跑 `cloudflared tunnel login` |

## 💡 二次开发

- **加新偏方**：编辑 `pianfang.html` 里的 `DATA` 数组，每条 `{cat, name, zhuzhi, material, steps, detail, note, source}`
- **改主题色**：每个 HTML 顶部 `:root` 里的 `--primary` `--gold` 变量
- **改字号**：4 档预设（small/medium/large/xlarge），用 `localStorage` 记忆

## ⚠️ 内容声明

本仓库收录的偏方、占卜内容**仅供文化研究与娱乐参考**，不构成任何医疗、法律或财务建议。如有疾病请遵医嘱。

## 📄 许可证

MIT License — 详见 `LICENSE` 文件。
