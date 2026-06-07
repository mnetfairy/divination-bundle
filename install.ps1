# 婚姻占卜术 · 掌中诀 - Windows 一键部署
# 需要：PowerShell 5+ 管理员权限运行

$ErrorActionPreference = "Stop"
Write-Host "🪄 婚姻占卜术·掌中诀  部署向导 (Windows)" -ForegroundColor Cyan
Write-Host "============================================"

# 1. Python
$py = $null
foreach ($c in @("python", "python3", "py")) {
    try { & $c --version 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { $py = $c; break } } catch {}
}
if (-not $py) { Write-Host "❌ 未检测到 Python，请先安装 Python 3.8+" -ForegroundColor Red; exit 1 }
Write-Host "✅ Python: $(& $py --version)" -ForegroundColor Green

# 2. cloudflared
if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
    Write-Host "⬇️ 下载 cloudflared..."
    $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
    $url = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-$arch.exe"
    $dst = "$env:LOCALAPPDATA\Programs\cloudflared\cloudflared.exe"
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    Invoke-WebRequest -Uri $url -OutFile $dst
    [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:LOCALAPPDATA\Programs\cloudflared", "User")
    $env:Path = $env:Path + ";$env:LOCALAPPDATA\Programs\cloudflared"
}
Write-Host "✅ cloudflared: $((Get-Command cloudflared).Source)" -ForegroundColor Green

# 3. 配置
$TUNNEL_NAME = if ($env:TUNNEL_NAME) { $env:TUNNEL_NAME } else { "divination-tunnel" }
$SUBDOMAIN = if ($env:SUBDOMAIN) { $env:SUBDOMAIN } else { "divination" }
$DOMAIN = $env:DOMAIN
if (-not $DOMAIN) { Write-Host "❌ 请先设置: `$env:DOMAIN = 'your-domain.com'" -ForegroundColor Red; exit 1 }
$FULL_DOMAIN = "$SUBDOMAIN.$DOMAIN"

# 4. 登录 + 创建隧道
$certPath = "$env:USERPROFILE\.cloudflared\cert.pem"
if (-not (Test-Path $certPath)) {
    Write-Host "⚠️ 即将打开浏览器授权..." -ForegroundColor Yellow
    cloudflared tunnel login
}
if (-not (cloudflared tunnel info $TUNNEL_NAME 2>$null)) {
    cloudflared tunnel create $TUNNEL_NAME
}
$TUNNEL_ID = (cloudflared tunnel info $TUNNEL_NAME | Select-String -Pattern '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' | Select-Object -First 1).Matches.Value
cloudflared tunnel route dns $TUNNEL_NAME $FULL_DOMAIN 2>$null

# 配置文件
$configDir = "$env:USERPROFILE\.cloudflared"
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
@"
tunnel: $TUNNEL_NAME
credentials-file: $configDir\$TUNNEL_ID.json

ingress:
  - hostname: $FULL_DOMAIN
    service: http://localhost:8080
  - service: http_status:404
"@ | Set-Content -Path "$configDir\config.yml" -Encoding UTF8

# 5. 启动
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "▶ 启动 HTTP 服务..." -ForegroundColor Cyan
Start-Process -FilePath $py -ArgumentList "$scriptDir\server.py" -WindowStyle Hidden -RedirectStandardOutput "$scriptDir\server.log" -RedirectStandardError "$scriptDir\server.err.log"
Start-Sleep -Seconds 2
Write-Host "▶ 启动 Cloudflare 隧道..." -ForegroundColor Cyan
Start-Process -FilePath "cloudflared" -ArgumentList "tunnel run $TUNNEL_NAME" -WindowStyle Hidden -RedirectStandardOutput "$scriptDir\tunnel.log" -RedirectStandardError "$scriptDir\tunnel.err.log"

Start-Sleep -Seconds 3
Write-Host "============================================" -ForegroundColor Green
Write-Host "🎉 部署完成！" -ForegroundColor Green
Write-Host "外网地址: https://$FULL_DOMAIN" -ForegroundColor Cyan
Write-Host "============================================"
