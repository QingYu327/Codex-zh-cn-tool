<#
  睡醒的夜猫子 · Codex 一键汉化   (WakeCat i18n)
  面向 OpenAI Codex Desktop / ChatGPT 桌面版（Microsoft Store MSIX 版 / 便携版）

  用法：双击同目录的「Codex一键汉化.cmd」，或命令行
        powershell -NoProfile -ExecutionPolicy Bypass -File ".\Codex一键汉化.ps1" -Action check

  可移植性：所有路径都取自环境变量（USERPROFILE / LOCALAPPDATA / PSScriptRoot），
  不写死本机用户名、盘符与版本号；换一台电脑可直接运行，无需安装任何依赖。

  与旧版第三方汉化包的本质区别：
    旧方案 = 把 app.asar 复制到用户目录再打补丁  ->  依赖 Node、占 1.8GB、
             每次商店更新都会失效、且会把官方 196 键的完整中文覆盖成 73 键的残缺中文。
    本方案 = 使用应用官方自带的 localeOverride 配置开关 + 官方已内置的 64 种语言资源，
             不再改动任何应用文件，升级后依然有效，完全离线，无需 VPN。
#>
[CmdletBinding()]
param(
    [ValidateSet('menu', 'check', 'apply', 'restore', 'languages', 'clean', 'net', 'launch', 'report')]
    [string]$Action = 'menu',
    [string]$Language = '',
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- 基础环境
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
try { $OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

if ($PSScriptRoot) { $script:Root = $PSScriptRoot }
else { $script:Root = Split-Path -Parent $MyInvocation.MyCommand.Definition }

$script:AppName   = '睡醒的夜猫子 · Codex 一键汉化'
$script:Version   = 'v1.1.0'
$script:CfgPath   = Join-Path $env:USERPROFILE '.wakecat-i18n.json'
$script:CodexHome = Join-Path $env:USERPROFILE '.codex'
$script:ConfigToml = Join-Path $script:CodexHome 'config.toml'
$script:CuConfig  = Join-Path $script:CodexHome 'computer-use\config.json'
$script:BackupDir    = Join-Path $script:Root 'backups'
$script:BackupDirAlt = Join-Path $env:LOCALAPPDATA 'Codex-i18n\backups'
$script:State     = @{}
$script:Probe     = $null

# 旧版第三方汉化包留下的副产物
$script:Leftovers = @(
    @{ Name = '旧汉化副本 (zh-cn-patched)';      Path = Join-Path $env:USERPROFILE '.codex\zh-cn-patched' },
    @{ Name = '旧补丁备份 (install-backups)';    Path = Join-Path $env:USERPROFILE '.codex\zh-cn-install-backups' },
    @{ Name = '旧插件备份 (.zh-cn-backups)';     Path = Join-Path $env:USERPROFILE '.codex\.zh-cn-backups' },
    @{ Name = '旧路径标记 (codex-desktop-path)'; Path = Join-Path $env:USERPROFILE '.codex\codex-desktop-path.txt' }
)

# ---------------------------------------------------------------- 显示工具
function Get-Cfg {
    $def = [ordered]@{
        appPath    = ''
        language   = 'zh-CN'
        proxy      = ''
        banner     = 'auto'
        autoBackup = $true
    }
    if (Test-Path -LiteralPath $script:CfgPath) {
        try {
            $j = Get-Content -LiteralPath $script:CfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($k in @($def.Keys)) { if ($null -ne $j.$k -and "$($j.$k)" -ne '') { $def[$k] = $j.$k } }
        } catch { }
    }
    [pscustomobject]$def
}

function Save-Cfg($cfg) {
    $json = $cfg | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($script:CfgPath, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-DisplayWidth([string]$s) {
    $w = 0
    foreach ($ch in $s.ToCharArray()) {
        $c = [int]$ch
        if (($c -ge 0x1100 -and $c -le 0x115F) -or ($c -ge 0x2E80 -and $c -le 0xA4CF) -or
            ($c -ge 0xAC00 -and $c -le 0xD7A3) -or ($c -ge 0xF900 -and $c -le 0xFAFF) -or
            ($c -ge 0xFE30 -and $c -le 0xFE6F) -or ($c -ge 0xFF00 -and $c -le 0xFF60) -or
            ($c -ge 0xFFE0 -and $c -le 0xFFE6)) { $w += 2 } else { $w += 1 }
    }
    $w
}

function PadR([string]$s, [int]$n) {
    $d = $n - (Get-DisplayWidth $s)
    if ($d -lt 1) { $d = 1 }
    $s + (' ' * $d)
}

function Get-ConWidth {
    try { $w = $Host.UI.RawUI.WindowSize.Width; if ($w -ge 40) { return [int]$w } } catch { }
    try { $w = [Console]::WindowWidth; if ($w -ge 40) { return [int]$w } } catch { }
    100
}

function Get-ContentWidth {
    $w = Get-ConWidth
    $c = $w - 8
    if ($c -gt 92) { $c = 92 }
    if ($c -lt 48) { $c = 48 }
    $c
}

function Test-Interactive {
    try { if ([Console]::IsInputRedirected) { return $false } } catch { }
    $true
}

function Center([string]$s) {
    $w = Get-ConWidth
    $d = [int](($w - (Get-DisplayWidth $s)) / 2)
    if ($d -lt 0) { $d = 0 }
    (' ' * $d) + $s
}

function Write-C([string]$text, [string]$color) {
    $old = $null; $hasOld = $false
    try { $old = $Host.UI.RawUI.ForegroundColor; $hasOld = $true } catch { }
    try {
        if ($color -and $hasOld) { $Host.UI.RawUI.ForegroundColor = $color }
        Write-Host $text
    } finally {
        if ($hasOld) { try { $Host.UI.RawUI.ForegroundColor = $old } catch { } }
    }
}

function Write-CN([string]$text, [string]$color) {
    $old = $null; $hasOld = $false
    try { $old = $Host.UI.RawUI.ForegroundColor; $hasOld = $true } catch { }
    try {
        if ($color -and $hasOld) { $Host.UI.RawUI.ForegroundColor = $color }
        Write-Host $text -NoNewline
    } finally {
        if ($hasOld) { try { $Host.UI.RawUI.ForegroundColor = $old } catch { } }
    }
}

function Fmt-Size([int64]$b) {
    if ($b -ge 1073741824) { return ('{0:N2} GB' -f ($b / 1073741824)) }
    if ($b -ge 1048576)    { return ('{0:N1} MB' -f ($b / 1048576)) }
    if ($b -ge 1024)       { return ('{0:N1} KB' -f ($b / 1024)) }
    return "$b B"
}

function Get-DirSize([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return [int64]0 }
    $item = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
    if ($item -and -not $item.PSIsContainer) { return [int64]$item.Length }
    $s = (Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    if ($null -eq $s) { return [int64]0 }
    [int64]$s
}

function Move-ToRecycleBin([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $true }

    # 首选：资源管理器「删除」动词 —— 等价于右键删除，进回收站
    try {
        $shell = New-Object -ComObject Shell.Application
        $parent = Split-Path -Parent $path
        $leaf = Split-Path -Leaf $path
        $ns = $shell.Namespace($parent)
        if ($ns) {
            $item = $ns.ParseName($leaf)
            if ($item) {
                $item.InvokeVerb('delete')
                # 删除由外壳异步执行，轮询确认（大目录可能要几秒）
                for ($i = 0; $i -lt 120; $i++) {
                    Start-Sleep -Milliseconds 250
                    if (-not (Test-Path -LiteralPath $path)) { return $true }
                }
            }
        }
    } catch { }

    # 兜底：Visual Basic 回收站 API
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
        if ((Get-Item -LiteralPath $path -Force).PSIsContainer) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                $path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        } else {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        }
    } catch { }

    return (-not (Test-Path -LiteralPath $path))
}

# ---------------------------------------------------------------- 定位应用
function Find-App {
    $cfg = Get-Cfg

    if ($cfg.appPath) {
        $p = $cfg.appPath
        if (Test-Path -LiteralPath (Join-Path $p 'resources\app.asar')) {
            return [pscustomobject]@{ Path = $p; Kind = '自定义'; Package = $null }
        }
        if (Test-Path -LiteralPath (Join-Path $p 'app\resources\app.asar')) {
            return [pscustomobject]@{ Path = (Join-Path $p 'app'); Kind = '自定义'; Package = $null }
        }
    }

    foreach ($proc in @(Get-Process -Name 'ChatGPT', 'Codex', 'codex' -ErrorAction SilentlyContinue)) {
        try {
            $dir = Split-Path -Parent $proc.Path
            for ($i = 0; $i -lt 4 -and $dir; $i++) {
                if (Test-Path -LiteralPath (Join-Path $dir 'resources\app.asar')) {
                    return [pscustomobject]@{ Path = $dir; Kind = '进程'; Package = $null }
                }
                $dir = Split-Path -Parent $dir
            }
        } catch { }
    }

    $pkgs = @(Get-AppxPackage -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -like 'OpenAI.*' -or $_.Name -like '*Codex*' -or $_.Name -like '*ChatGPT*' })
    foreach ($pk in $pkgs) {
        $cand = Join-Path $pk.InstallLocation 'app'
        if (Test-Path -LiteralPath (Join-Path $cand 'resources\app.asar')) {
            return [pscustomobject]@{ Path = $cand; Kind = 'MSIX'; Package = $pk }
        }
        if (Test-Path -LiteralPath (Join-Path $pk.InstallLocation 'resources\app.asar')) {
            return [pscustomobject]@{ Path = $pk.InstallLocation; Kind = 'MSIX'; Package = $pk }
        }
    }

    $parents = @(
        (Join-Path $env:LOCALAPPDATA 'Programs'),
        'C:\Program Files\Codex',
        "$env:ProgramFiles\Codex",
        'D:\soft', 'E:\soft',
        [Environment]::GetFolderPath('Desktop'),
        (Join-Path $env:USERPROFILE 'Downloads')
    )
    foreach ($parent in $parents) {
        if (-not (Test-Path -LiteralPath $parent)) { continue }
        foreach ($d in @(Get-ChildItem -LiteralPath $parent -Directory -Force -ErrorAction SilentlyContinue |
                         Where-Object { $_.Name -match 'Codex|ChatGPT' })) {
            if (Test-Path -LiteralPath (Join-Path $d.FullName 'resources\app.asar')) {
                return [pscustomobject]@{ Path = $d.FullName; Kind = '便携版'; Package = $null }
            }
            if (Test-Path -LiteralPath (Join-Path $d.FullName 'app\resources\app.asar')) {
                return [pscustomobject]@{ Path = (Join-Path $d.FullName 'app'); Kind = '便携版'; Package = $null }
            }
        }
    }

    $null
}

# ---------------------------------------------------------------- asar 读取
function Get-AsarHeaderJson([string]$asar) {
    $fs = [System.IO.File]::Open($asar, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $head = New-Object byte[] 8
        $read = 0
        while ($read -lt 8) {
            $n = $fs.Read($head, $read, 8 - $read); if ($n -le 0) { break }; $read += $n
        }
        $hdrPickle = [BitConverter]::ToUInt32($head, 4)
        $raw = New-Object byte[] $hdrPickle
        $read = 0
        while ($read -lt $hdrPickle) {
            $n = $fs.Read($raw, $read, $hdrPickle - $read); if ($n -le 0) { break }; $read += $n
        }
    } finally { $fs.Close() }
    $jsonLen = [BitConverter]::ToUInt32($raw, 4)
    [pscustomobject]@{
        Json      = [System.Text.Encoding]::UTF8.GetString($raw, 8, $jsonLen)
        DataStart = [int64](8 + $hdrPickle)
    }
}

function Read-AsarEntry([string]$asar, [int64]$dataStart, [int64]$offset, [int]$size) {
    $fs = [System.IO.File]::Open($asar, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $fs.Seek($dataStart + $offset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $buf = New-Object byte[] $size
        $read = 0
        while ($read -lt $size) {
            $n = $fs.Read($buf, $read, $size - $read); if ($n -le 0) { break }; $read += $n
        }
        return [System.Text.Encoding]::UTF8.GetString($buf, 0, $read)
    } finally { $fs.Close() }
}

function Get-AppProbe {
    param([switch]$Refresh)
    if (-not $Refresh -and $script:Probe) { return $script:Probe }

    $r = [ordered]@{
        Found = $false; Kind = ''; AppDir = ''; Asar = ''; AsarSize = 0
        Version = ''; FamilyName = ''; Locales = @(); ZhKeys = 0; ZhSize = 0
        WebZhSize = 0; WebZhName = ''; Error = ''
    }

    $app = Find-App
    if ($null -eq $app) {
        $r.Error = '未找到 Codex / ChatGPT 桌面版'
        $script:Probe = [pscustomobject]$r
        return $script:Probe
    }

    $asar = Join-Path $app.Path 'resources\app.asar'
    $r.Found = $true
    $r.Kind = $app.Kind
    $r.AppDir = $app.Path
    $r.Asar = $asar
    if (Test-Path -LiteralPath $asar) { $r.AsarSize = (Get-Item -LiteralPath $asar).Length }

    if ($app.Package) {
        $r.Version = "$($app.Package.Version)"
        $r.FamilyName = $app.Package.PackageFamilyName
    }
    if (-not $r.Version) {
        $exe = @('ChatGPT.exe', 'Codex.exe') | ForEach-Object { Join-Path $app.Path $_ } |
               Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if ($exe) { $r.Version = (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion }
    }

    try {
        $hdr = Get-AsarHeaderJson $asar
        # app.asar 头部是嵌套目录树，必须解析成对象再取节点（不是斜杠路径）
        $h = $hdr.Json | ConvertFrom-Json

        $nm = $h.files.'native-menu-locales'
        if ($nm) {
            $r.Locales = @($nm.files.PSObject.Properties.Name | ForEach-Object { $_ -replace '\.json$', '' }) | Sort-Object
            $zn = $nm.files.'zh-CN.json'
            if ($zn) {
                $r.ZhSize = [int]$zn.size
                $txt = Read-AsarEntry $asar $hdr.DataStart ([int64]$zn.offset) $r.ZhSize
                try { $r.ZhKeys = @(($txt | ConvertFrom-Json).PSObject.Properties).Count }
                catch { $r.ZhKeys = -1 }
            }
        }

        $wvAssets = $null
        if ($h.files.webview) { $wvAssets = $h.files.webview.files.assets }
        if ($wvAssets -and $wvAssets.files) {
            foreach ($p in $wvAssets.files.PSObject.Properties) {
                if ($p.Name -like 'zh-CN*.js') { $r.WebZhName = $p.Name; $r.WebZhSize = [int]$p.Value.size }
            }
        }
    } catch {
        $r.Error = "读取 app.asar 失败: $($_.Exception.Message)"
    }

    $script:Probe = [pscustomobject]$r
    $script:Probe
}

# ---------------------------------------------------------------- 配置读写
function Get-TomlLocale([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $lines = [System.IO.File]::ReadAllText($path) -split "`r?`n"
    $inDesktop = $false
    foreach ($ln in $lines) {
        if ($ln -match '^\s*\[') { $inDesktop = ($ln -match '^\s*\[\s*desktop\s*\]\s*$') }
        if ($inDesktop -and $ln -match '^\s*localeOverride\s*=\s*"?([^"#]*)') {
            return $Matches[1].Trim().Trim('"')
        }
    }
    $null
}

function Set-TomlLocale([string]$path, [string]$locale, [switch]$Remove) {
    # 新环境上 %USERPROFILE%\.codex 可能还不存在（应用从未启动过），先建目录
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-C "        已创建目录 $dir" 'DarkGray'
    }
    $raw = ''
    if (Test-Path -LiteralPath $path) { $raw = [System.IO.File]::ReadAllText($path) }
    $nl = if ($raw -match "`r`n") { "`r`n" } else { "`n" }
    $lines = @()
    if ($raw.Length -gt 0) { $lines = $raw -split "`r?`n" }

    $secStart = -1; $keyIdx = -1; $secEnd = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[\s*desktop\s*\]\s*$') {
            $secStart = $i
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match '^\s*\[') { $secEnd = $j; break }
            }
            break
        }
    }
    if ($secStart -ge 0) {
        for ($i = $secStart + 1; $i -lt $secEnd; $i++) {
            if ($lines[$i] -match '^\s*localeOverride\s*=') { $keyIdx = $i; break }
        }
    }

    $out = New-Object System.Collections.Generic.List[string]
    if ($Remove) {
        if ($keyIdx -ge 0) {
            for ($i = 0; $i -lt $lines.Count; $i++) { if ($i -ne $keyIdx) { $out.Add($lines[$i]) } }
        } else {
        $lines | ForEach-Object { $out.Add($_) }
        }
        # 去掉可能的空尾行
        while ($out.Count -gt 0 -and $out[$out.Count - 1].Trim() -eq '') { $out.RemoveAt($out.Count - 1) }
        $text = ($out -join $nl) + $nl
        [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
        return
    }

    if ($keyIdx -ge 0) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($i -eq $keyIdx) { $out.Add('localeOverride = "' + $locale + '"') } else { $out.Add($lines[$i]) }
        }
    } elseif ($secStart -ge 0) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $out.Add($lines[$i])
            if ($i -eq $secStart) { $out.Add('localeOverride = "' + $locale + '"') }
        }
    } else {
        $lines | ForEach-Object { $out.Add($_) }
        while ($out.Count -gt 0 -and $out[$out.Count - 1].Trim() -eq '') { $out.RemoveAt($out.Count - 1) }
        $out.Add('')
        $out.Add('[desktop]')
        $out.Add('localeOverride = "' + $locale + '"')
    }
    $text = ($out -join $nl) + $nl
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Ensure-Backup([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    # 备份优先放脚本同级 backups\；该位置不可写（例如脚本放在只读目录）时自动退到
    # %LOCALAPPDATA%。备份只是保险，失败不阻断主流程。每个文件只保留最近 5 份。
    foreach ($d in @($script:BackupDir, $script:BackupDirAlt)) {
        if (-not $d) { continue }
        try {
            if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $leaf  = Split-Path -Leaf $path
            $dest  = Join-Path $d ($leaf + '.' + $stamp + '.bak')
            Copy-Item -LiteralPath $path -Destination $dest -Force
            Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like ($leaf + '.*.bak') } |
                Sort-Object LastWriteTime -Descending | Select-Object -Skip 5 |
                ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -Confirm:$false -ErrorAction SilentlyContinue }
            return $dest
        } catch { }
    }
    Write-C '        [!] 备份目录不可写，已跳过备份（不影响汉化本身）。' 'Yellow'
    $null
}

# 官方中文语言包缺少 computerUseOverlay 词条，应用会回退成英文，这里补上
function Set-ComputerUseLocale([string]$locale, [switch]$Reset) {
    if (-not (Test-Path -LiteralPath $script:CuConfig)) { return 'not-found' }
    [void](Ensure-Backup $script:CuConfig)
    try {
        $j = Get-Content -LiteralPath $script:CuConfig -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch { return 'parse-error' }

    if (-not $j.PSObject.Properties['strings']) {
        $j | Add-Member -NotePropertyName strings -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    if (-not $j.PSObject.Properties['locale']) {
        $j | Add-Member -NotePropertyName locale -NotePropertyValue '' -Force
    }

    if ($Reset) {
        $j.locale = ''
        $j.strings.usingComputer = 'ChatGPT is using your computer'
        $j.strings.escToCancel = 'Esc to cancel'
        $result = 'reset'
    } elseif ($locale -eq 'zh-CN') {
        $j.locale = 'zh-CN'
        $j.strings.usingComputer = 'ChatGPT 正在使用你的电脑'
        $j.strings.escToCancel = '按 Esc 取消'
        $result = 'zh'
    } elseif ($locale -eq 'zh-TW' -or $locale -eq 'zh-HK') {
        $j.locale = $locale
        $j.strings.usingComputer = 'ChatGPT 正在使用你的電腦'
        $j.strings.escToCancel = '按 Esc 取消'
        $result = 'zh'
    } else {
        $j.locale = $locale
        $result = 'other'
    }

    $json = $j | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($script:CuConfig, $json, (New-Object System.Text.UTF8Encoding($false)))
    $result
}

# ---------------------------------------------------------------- 横幅
$BannerFull = @(
    '                             ▄▄▄▄▄▄        ▄     ▄               ▄▄               ▄  ▄   ▄                       '
    '  ▄▄▄▄ ██████▀▀▀    ▀▀████▀▀ █▀▀▀▀█       ██    ██         ▄▄▄▄▄▄██▄▄▄▄▄▄     ▀█▄█▀▄▄██▄▄█▄▄      ▀▀▀▀▀▀▀▀███▀   '
    '  █  █▄▄▄▄▄█▄▄▄▄▄    ▄████▄▄ █▀▀▀▀█     ██████ ▄██████        █  ▀█▀          ▄███ ▀▀██▀▀█▀▀▀          ▄▄█▀      '
    '  █▀██  █▀ █ ▀█     ████████ ██████     ██   █▄█▀    █       ██  ███████     ▀▀  █  ▄█▄▄▄█▄▄     ▄     ██     ▄  '
    '  █▄▄█▄█████████▄   ▀██▀████▄█▄██▄▄     ██▄▄▄█  ██   █     ▄██ ▄██ ▄▄ █▀       ▄██ ██▀▀██▀██    ▀▀▀▀▀▀▀██▀▀▀▀▀▀▀ '
    '  █▀▀█  █  █  █      █▀  ▀███▀▀██▀▀     ██   █   ██ ██    ██▀█ ▀▀██ ▀██      ▄█▀ █ ██▄▄██▄██           ██        '
    '  █▄██▀█▀█████▀█▀   ▄█▀▀▀▀██ ▀▀██▀▀     ██▄▄▄█      ██       █    ███▀           █ ██  ██ ██           ██        '
    ' ▀█  ▀ ▄▄▄▄█▄▄▄▄    ▄███████▄▄▄██▄▄▄    ██▀▀▀█   ▄▄▄█▀       █ ▄▄██▀▀██▄▄▄    ▄▄█▀ █████████         ███▀        '
    '                     ▀    ▀                       ▀▀         ▀ ▀▀      ▀▀      ▀    ▀      ▀                     '
)
$BannerMid = @(
    '                  ▄▄▄▄▄▄  ▄▄▄▄▄       ▄    ▄▄             ▄▄             ▄  ▄  ▄▄       ▄            '
    ' ▄███ ▀▀▀██▀▀▀    ▀▀█▀█▀▀██▄▄▄█▀     ▄█    ██       ▄████████████     ▀██▀▄▄█▄▄██▄▄     ▀▀▀▀▀▀███▀   '
    ' ██▄██████████    ██████▄██▀▀▀█▄    █▀▀▀█ ▄█▀▀▀█       █▄ ▄█▄▄▄      ▄▄▀█   █▀ ██           ▄█▀      '
    ' ██▀█▄▄█▄▄█▄█▄    ███████ █▀█▀▀     █   ██▀▄   █      ██ ▄█▀▀▀▀█        ██ ███████    ▄▄▄▄▄▄██▄▄▄▄▄▄ '
    ' ████▀▀█▀▀█▀█▀▀   ██▀ ▀████▀██▀▀    █▀▀▀█  ▀█  █    ▄███▄██▄▀▄█▀      ▄███ █▄▄█▄▄█          ██       '
    ' ██▄██▄████▄██▄   ███████▀▄▄██▄     █   █   ▀  █    ▀ ██  ▀█▄█▀      ▀▀ ██ █▀▀█▀▀█          ██       '
    ' ██▀█ ▄▄▄██▄▄▄    ██▄▄▄██▄▄▄█▄▄▄    █▀▀▀█   ▄▄▄█      ██ ▄▄█▀█▄▄▄     ▄▄█  █▄██▄▄█        ▄▄██       '
    '       ▀▀▀▀▀▀▀    ▀    ▀▀           ▀       ▀▀▀       ▀▀ ▀     ▀▀     ▀▀   ▀     ▀                   '
)
$BannerSmall = @(
    '          ▄▄    ▄▄▄▄▄▄▄▄▄▄▄▄     ▄▄   ▄▄           ▄▄         ▄ ▄▄ ▄  ▄       ▄▄▄▄▄▄▄▄   '
    ' ██▀█ ▀▀██▀▀     ████ ██▄▄██    ▄██▄  █▄▄▄    ▀██████▀▀▀▀▀    ▀█▀█▄██▄█▄▄     ▀▀▀▀▄██▀   '
    ' ████▀█▀█▀▀█▀   ██████▀█▄▄██    █▀▀█▄█▀  ██     ██ ▄█▄▄▄▄    █▀▀█  █▄ █▄         ██      '
    ' █▄▄█████████   ██████▄█▄█▄▄    █▄▄█▀ █▄ ██    ██ ▄█ ▄ █▀     ▄██ █▀▀█▀██   ▀▀▀▀▀██▀▀▀▀▀ '
    ' ██▀█▄█▄█▄▄█▄   ██▄▄██▀▄██▄▄    █  ██  ▀ ██   ▀▀█▀▀▀█▄█▀     █▀ █ ███████        ██      '
    ' ██▀█   ██      ██▄▄██▄▄██▄▄    █████   ▄█      █ ▄▄███▄▄      ▄█ █▄▄█▄██       ▄██      '
    '      ▀▀▀▀▀▀    ▀    ▀▀▀▀▀▀▀    ▀      ▀▀       ▀ ▀▀   ▀▀▀    ▀▀  ▀    ▀▀       ▀        '
)
$BannerCompact = @(
    '  ╔════════════════════════════════════════════╗'
    '  ║  睡 醒 的 夜 猫 子  ·  Codex 一键汉化      ║'
    '  ╚════════════════════════════════════════════╝'
)

function Show-Banner {
    $cfg = Get-Cfg
    $mode = "$($cfg.banner)"
    $w = Get-ConWidth
    $fellBack = $false
    if ($mode -eq 'compact') { $lines = $BannerCompact }
    elseif ($mode -eq 'full') { $lines = $BannerFull }
    elseif ($w -ge 118) { $lines = $BannerFull }
    elseif ($w -ge 106) { $lines = $BannerMid }
    elseif ($w -ge 94)  { $lines = $BannerSmall }
    else { $lines = $BannerCompact; $fellBack = $true }

    Write-Host ''
    foreach ($ln in $lines) {
        Write-C (Center $ln) 'Cyan'
    }
    Write-Host ''
    $sub = "$($script:Version)   ·   " + (Get-Date -Format 'yyyy-MM-dd HH:mm')
    Write-C (Center $sub) 'DarkGray'
    if ($fellBack) { Write-C (Center '（窗口较窄，已用紧凑横幅；[7] 设置里可改为 full）') 'DarkGray' }
    Write-Host ''
}

# ---------------------------------------------------------------- 状态面板
function Get-PanelRows {
    $p = Get-AppProbe
    $cfg = Get-Cfg
    $toml = Get-TomlLocale $script:ConfigToml
    $rows = New-Object System.Collections.Generic.List[object]

    if ($p.Found) {
        $ver = if ($p.Version) { $p.Version } else { '未知' }
        $rows.Add(@('应用', "$ver  [$($p.Kind)]", 'Gray'))
        $rows.Add(@('安装路径', $p.AppDir, 'DarkGray'))
        if ($p.Locales.Count -gt 0) {
            $ok = $p.ZhKeys -gt 0
            $txt = "官方语言 $($p.Locales.Count) 种 · 原生菜单中文 $($p.ZhKeys) 键 · Webview $(Fmt-Size $p.WebZhSize)"
            $rows.Add(@('中文资源', $txt, $(if ($ok) { 'Green' } else { 'Red' })))
        } else {
            $rows.Add(@('中文资源', '未检测到 native-menu-locales', 'Red'))
        }
    } else {
        $rows.Add(@('应用', '未找到 (菜单 [7] 可手动指定路径)', 'Red'))
    }

    if ($toml) {
        $rows.Add(@('界面语言', "localeOverride = `"$toml`"", $(if ($toml -eq 'zh-CN') { 'Green' } else { 'Yellow' })))
    } else {
        $rows.Add(@('界面语言', '未设置（跟随系统）', 'Yellow'))
    }

    if (Test-Path -LiteralPath $script:CuConfig) {
        $cuLoc = ''
        try { $cuLoc = (Get-Content -LiteralPath $script:CuConfig -Raw -Encoding UTF8 | ConvertFrom-Json).locale } catch { }
        $rows.Add(@('覆盖层', "computer-use locale = `"$cuLoc`"", $(if ($cuLoc -eq 'zh-CN') { 'Green' } else { 'Yellow' })))
    }

    $lsum = @()
    foreach ($it in $script:Leftovers) {
        if (Test-Path -LiteralPath $it.Path) {
            $sz = Get-DirSize $it.Path
            if ($sz -gt 0) { $lsum += ("$($it.Name.Split(' ')[0]) $(Fmt-Size $sz)") }
        }
    }
    if ($lsum.Count -gt 0) {
        $lsTxt = ($lsum -join ' · ') + '   (菜单 [6] 可清理)'
        $rows.Add(@('副产物', $lsTxt, 'Yellow'))
    } else {
        $rows.Add(@('副产物', '无', 'Green'))
    }

    if ($cfg.proxy) { $rows.Add(@('网络代理', $cfg.proxy, 'Gray')) }
    else { $rows.Add(@('网络代理', '未设置（直连）', 'DarkGray')) }

    $rows.Add(@('配置', $script:CfgPath, 'DarkGray'))
    $rows
}

function Show-Panel {
    $rows = Get-PanelRows
    $CW = Get-ContentWidth
    $labelW = 13
    $valW = $CW - 7 - $labelW
    if ($valW -lt 16) { $valW = 16 }
    $bar = '  +' + ('-' * ($CW - 4)) + '+'

    Write-C $bar 'DarkGray'
    $t = ' 当前配置 '
    Write-C ('  |' + $t + ('-' * ($CW - 4 - (Get-DisplayWidth $t))) + '|') 'DarkGray'

    foreach ($r in $rows) {
        $lbl = PadR ('  ' + $r[0]) $labelW
        $val = "$($r[1])"
        if ((Get-DisplayWidth $val) -gt $valW) {
            while ($val.Length -gt 1 -and (Get-DisplayWidth ($val + '…')) -gt $valW) {
                $val = $val.Substring(0, $val.Length - 1)
            }
            $val = $val.TrimEnd() + '…'
        }
        Write-CN '  | ' 'DarkGray'
        Write-CN $lbl 'White'
        Write-CN '| ' 'DarkGray'
        Write-CN (PadR $val $valW) $r[2]
        Write-C '|' 'DarkGray'
    }
    Write-C $bar 'DarkGray'
}

# ---------------------------------------------------------------- 动作
function Resolve-Language([string]$want) {
    $p = Get-AppProbe
    if ($p.Locales.Count -gt 0 -and ($p.Locales -contains $want)) { return $want }
    $alias = @{
        'zh' = 'zh-CN'; 'cn' = 'zh-CN'; 'zh-cn' = 'zh-CN'; '简体' = 'zh-CN'; '中文' = 'zh-CN'
        'zh-tw' = 'zh-TW'; 'zh-hk' = 'zh-HK'; 'en' = 'en-US'; 'ja' = 'ja-JP'; 'ko' = 'ko-KR'
    }
    if ($alias.ContainsKey($want.ToLower())) { return $alias[$want.ToLower()] }
    $want
}

function Invoke-Apply([string]$locale) {
    $p = Get-AppProbe -Refresh
    if (-not $p.Found) { Write-C '  [X] 未找到 ChatGPT / Codex 桌面版，请用菜单 [7] 手动指定安装路径。' 'Red'; return }

    Write-Host ''
    Write-C '  [1/4] 读取官方语言资源…' 'Cyan'
    if ($p.ZhKeys -gt 0) {
        Write-C ("        应用内置 $($p.Locales.Count) 种语言；简体中文资源：原生菜单 $($p.ZhKeys) 键 · Webview $(Fmt-Size $p.WebZhSize)") 'Gray'
        Write-C "        目标语言：$locale" 'Gray'
        Write-C '        资源随应用一起安装，完全离线可用，不需要下载任何语言包。' 'Gray'
    } else {
        Write-C '        [!] 未读到 native-menu-locales/zh-CN.json，此版本可能已移除中文资源。' 'Yellow'
    }

    Write-C '  [2/4] 备份配置文件…' 'Cyan'
    $bak = Ensure-Backup $script:ConfigToml
    if ($bak) { Write-C "        $bak" 'DarkGray' } else { Write-C '        config.toml 不存在，将新建。' 'DarkGray' }

    Write-C '  [3/4] 写入 localeOverride…' 'Cyan'
    Set-TomlLocale $script:ConfigToml $locale
    $now = Get-TomlLocale $script:ConfigToml
    if ($now -eq $locale) { Write-C "        config.toml -> localeOverride = `"$locale`"" 'Green' }
    else { Write-C "        [!] 写入后读回为 `"$now`"，请检查 config.toml。" 'Yellow' }

    Write-C '  [4/4] 同步「正在使用你的电脑」覆盖层…（尽力而为）' 'Cyan'
    $cu = Set-ComputerUseLocale $locale
    switch ($cu) {
        'zh'         {
            Write-C '        computer-use/config.json 已写入中文覆盖层文案' 'Green'
            Write-C '        [!] 该文件由应用自己托管：实测应用启动时会用内置英文默认值重写它。' 'DarkGray'
            Write-C '            若覆盖层仍显示英文，属应用自身未翻译这两条文案，不影响界面主体语言。' 'DarkGray'
        }
        'other'      { Write-C "        computer-use/config.json locale 已设为 $locale" 'Green' }
        'not-found'  { Write-C '        未生成 computer-use/config.json，首次运行应用后会自动创建。' 'DarkGray' }
        'parse-error'{ Write-C '        [!] computer-use/config.json 解析失败，已跳过。' 'Yellow' }
        default      { Write-C "        $cu" 'DarkGray' }
    }

    Write-Host ''
    Write-C '  汉化设置已就绪。界面语言由应用官方开关控制，' 'Green'
    Write-C '  完全离线完成，不需要 VPN，且应用商店升级后依然有效。' 'Green'
    Write-C '  若界面仍是英文：完全退出应用（托盘右键退出）后重新启动即可。' 'Gray'
}

function Invoke-Check {
    $p = Get-AppProbe -Refresh
    Write-Host ''
    Write-C '  === 环境体检 ================================================' 'Cyan'
    $arch = if ([System.Environment]::Is64BitProcess) { 'x64' } else { 'x86' }
    Write-C ("  运行环境        : PowerShell $($PSVersionTable.PSVersion)  ·  $arch  ·  $([System.Environment]::OSVersion.Version)") 'Gray'
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-C '                    [!] 建议 PowerShell 5.1 及以上（Win10 / 11 均自带）' 'Yellow'
    }
    $codexOk = if (Test-Path -LiteralPath $script:CodexHome) { '已存在' } else { '尚未生成（首次运行应用后出现）' }
    Write-C ("  用户配置目录    : $($script:CodexHome)   [$codexOk]") 'Gray'
    Write-C ("  自身位置        : $($script:Root)") 'Gray'
    Write-Host ''
    if ($p.Found) {
        Write-C ("  应用            : $($p.Version)  [$($p.Kind)]") 'White'
        Write-C ("  安装路径        : $($p.AppDir)") 'Gray'
        Write-C ("  app.asar        : $(Fmt-Size $p.AsarSize)") 'Gray'
        if ($p.FamilyName) { Write-C ("  包标识          : $($p.FamilyName)") 'Gray' }
    } else {
        Write-C '  应用            : 未找到' 'Red'
    }
    if ($p.Error) { Write-C ("  读取错误        : $($p.Error)") 'Red' }

    Write-Host ''
    if ($p.Locales.Count -gt 0) {
        Write-C ("  官方语言总数    : $($p.Locales.Count)") 'White'
        if ($p.Locales -contains 'zh-CN') {
            Write-C ("  简体中文资源    : 原生菜单 $($p.ZhKeys) 键 · Webview $(Fmt-Size $p.WebZhSize)   [已内置]") 'Green'
        } else {
            Write-C '  简体中文资源    : 缺失' 'Red'
        }
    }
    $toml = Get-TomlLocale $script:ConfigToml
    Write-C ("  当前 localeOverride : " + $(if ($toml) { $toml } else { '(未设置)' })) 'White'
    if (Test-Path -LiteralPath $script:CuConfig) {
        $cu = ''
        try {
            $o = Get-Content -LiteralPath $script:CuConfig -Raw -Encoding UTF8 | ConvertFrom-Json
            $cu = "locale=$($o.locale)  usingComputer=`"$($o.strings.usingComputer)`""
        } catch { $cu = '(解析失败)' }
        Write-C ("  计算机使用覆盖层    : $cu") 'Gray'
    } else {
        Write-C '  计算机使用覆盖层    : 尚未生成（首次运行应用后出现）' 'DarkGray'
    }

    Write-Host ''
    Write-C '  副产物占用：' 'Cyan'
    $any = $false
    foreach ($it in $script:Leftovers) {
        if (Test-Path -LiteralPath $it.Path) {
            $any = $true
            Write-C ("    - " + (PadR $it.Name 30) + (Fmt-Size (Get-DirSize $it.Path))) 'Yellow'
            Write-C ("      $($it.Path)") 'DarkGray'
        }
    }
    if (-not $any) { Write-C '    (无)' 'Green' }

    Write-Host ''
    Write-C '  结论：' 'Cyan'
    if ($p.Found -and $p.ZhKeys -gt 0) {
        if ($toml -like 'zh*') {
            Write-C "    [OK] 官方中文资源完整，localeOverride = `"$toml`"，界面应为中文。" 'Green'
        } else {
            Write-C '    [!] 中文资源完整，但 localeOverride 未指向中文，请执行 [1] 一键汉化。' 'Yellow'
        }
    } elseif ($p.Found) {
        Write-C '    [!] 未检测到内置中文资源，该版本可能不提供简体中文。' 'Yellow'
    }
    Write-C '    旧版第三方汉化包（复制 app.asar 到用户目录那套）在此版本上属于负优化，不建议使用。' 'DarkGray'
}

function Invoke-Languages([string]$pick) {
    $p = Get-AppProbe -Refresh
    if (-not $p.Found) { Write-C '  [X] 未找到应用。' 'Red'; return }
    if ($p.Locales.Count -eq 0) { Write-C '  [X] 未读到语言清单。' 'Red'; return }

    if ($pick) {
        $code = Resolve-Language $pick
        if ($p.Locales -notcontains $code) {
            Write-C "  [X] 应用不提供语言 `"$code`"，当前可选：$($p.Locales -join ', ')" 'Red'
            return
        }
        Invoke-Apply $code
        return
    }

    Write-Host ''
    Write-C ("  应用内置 $($p.Locales.Count) 种语言（6 列）：") 'Cyan'
    Write-Host ''
    $i = 0
    foreach ($l in $p.Locales) {
        $i++
        Write-Host '    ' -NoNewline
        if ($l -eq 'zh-CN') { Write-CN (PadR $l 11) 'Green' } else { Write-CN (PadR $l 11) 'Gray' }
        if ($i % 6 -eq 0) { Write-Host '' }
    }
    if ($i % 6 -ne 0) { Write-Host '' }
    Write-Host ''
    Write-C '  简体中文 = zh-CN（推荐）   繁体 = zh-TW / zh-HK   英文 = 留空或用 [4] 还原' 'DarkGray'
    Write-Host ''
    if (-not (Test-Interactive)) {
        Write-C '  （非交互模式，仅列出清单，未做任何修改）' 'DarkGray'
        return
    }
    $ans = Read-Host '  输入语言代码（直接回车取消）'
    if (-not $ans) { return }
    Invoke-Languages $ans
}

function Invoke-Restore {
    Write-Host ''
    Write-C '  还原英文设置…' 'Cyan'
    if (Test-Path -LiteralPath $script:ConfigToml) {
        $bak = Ensure-Backup $script:ConfigToml
        Set-TomlLocale $script:ConfigToml '' -Remove
        Write-C ("    config.toml 已移除 localeOverride" + $(if ($bak) { "（备份：$bak）" } else { '' })) 'Green'
    } else {
        Write-C '    config.toml 不存在，无需处理。' 'Gray'
    }
    $cu = Set-ComputerUseLocale '' -Reset
    if ($cu -eq 'reset') { Write-C '    computer-use/config.json 已还原为英文' 'Green' }
    elseif ($cu -eq 'not-found') { Write-C '    computer-use/config.json 不存在，无需处理。' 'Gray' }
    Write-Host ''
    Write-C '  设置类改动已撤销。应用本身从未被修改，无需更深入还原。' 'Gray'
}

function Invoke-Clean([switch]$Force) {
    $items = @()
    foreach ($it in $script:Leftovers) {
        if (Test-Path -LiteralPath $it.Path) {
            $items += [pscustomobject]@{ Name = $it.Name; Path = $it.Path; Size = (Get-DirSize $it.Path) }
        }
    }
    if ($items.Count -eq 0) { Write-C '  没有需要清理的副产物。' 'Green'; return }

    $total = ($items | Measure-Object -Property Size -Sum).Sum
    Write-Host ''
    Write-C '  以下为旧版汉化包留下的副产物，均为可再生的应用副本/备份：' 'Cyan'
    Write-Host ''
    foreach ($x in $items) {
        Write-C ("    - " + (PadR $x.Name 32) + (PadR (Fmt-Size $x.Size) 12)) 'Yellow'
        Write-C ("      $($x.Path)") 'DarkGray'
    }
    Write-Host ''
    Write-C ("  合计可释放：$(Fmt-Size $total)") 'White'
    Write-C '  这些文件当前未被使用（应用走的是官方入口），删除不影响应用运行，' 'Gray'
    Write-C '  如需重做旧版汉化副本，可随时用其它脚本从 WindowsApps 重新复制。' 'Gray'

    if (-not $Force) {
        Write-Host ''
        if (-not (Test-Interactive)) {
            Write-C '  非交互模式：未获得确认，没有删除任何内容。确需清理请加 -Yes 参数。' 'Yellow'
            return
        }
        Write-C '  将移入回收站（可在回收站还原）。确认请回复 y：' 'White'
        $ans = Read-Host '  ###'
        if ($ans -notmatch '^(y|Y|yes|YES|是)$') { Write-C '  已取消。' 'Gray'; return }
    }

    Write-Host ''
    foreach ($x in $items) {
        $ok = Move-ToRecycleBin $x.Path
        if ($ok) { Write-C ("  [OK] 已移入回收站  " + $x.Name) 'Green' }
        else { Write-C ("  [!!] 失败         " + $x.Name + "  <- 可能被占用，请关闭应用后重试") 'Red' }
    }
    Write-Host ''
    Write-C '  完成。回收站仍占用磁盘空间，确认无误后清空回收站即可真正释放。' 'Yellow'
    Get-AppProbe -Refresh | Out-Null
}

function Invoke-Net {
    $cfg = Get-Cfg
    Write-Host ''
    Write-C '  === 网络与语言包检测 ========================================' 'Cyan'
    Write-C '  说明：本工具的汉化完全离线，不需要任何联网操作。' 'Green'
    Write-C '        这里只是帮你确认应用联网是否正常、代理是否可用。' 'Gray'
    Write-Host ''

    $targets = @(
        @{ N = 'ChatGPT / Codex 服务'; U = 'https://chatgpt.com' },
        @{ N = 'OpenAI API';           U = 'https://api.openai.com' },
        @{ N = 'GitHub（汉化包来源）';  U = 'https://api.github.com' }
    )
    foreach ($t in $targets) {
        foreach ($mode in @('direct', 'proxy')) {
            if ($mode -eq 'proxy' -and -not $cfg.proxy) { continue }
            $label = if ($mode -eq 'direct') { '直连' } else { "代理 $($cfg.proxy)" }
            $okTxt = ''; $col = 'Red'
            try {
                $req = @{ Uri = $t.U; Method = 'Head'; TimeoutSec = 8; UseBasicParsing = $true }
                if ($mode -eq 'proxy') { $req['Proxy'] = $cfg.proxy }
                Invoke-WebRequest @req | Out-Null
                $okTxt = '可达'; $col = 'Green'
            } catch {
                $okTxt = '不可达'
                if ("$($_.Exception.Message)" -match 'timed out|超时') { $okTxt = '超时' }
            }
            Write-Host ('    ' + (PadR $t.N 22)) -NoNewline
            Write-Host (PadR $label 24) -NoNewline
            Write-C $okTxt $col
        }
    }
    Write-Host ''
    Write-C '  语言包说明：中文资源已内置于应用，' 'White'
    Write-C '  只要上面「直连」能通（或配置代理后能通），应用功能就是完整的；' 'White'
    Write-C '  连不上只影响登录/对话，不影响界面中文。' 'White'
}

function Invoke-Launch {
    $p = Get-AppProbe
    if (-not $p.Found) { Write-C '  [X] 未找到应用。' 'Red'; return }

    if ($p.FamilyName) {
        $appId = $null
        # AppDir 是包根下的 app\ 子目录，AppxManifest.xml 在包根（只要上跳一层）
        $mf = Join-Path (Split-Path -Parent $p.AppDir) 'AppxManifest.xml'
        if (Test-Path -LiteralPath $mf) {
            try {
                $x = [xml](Get-Content -LiteralPath $mf -Raw -Encoding UTF8)
                $appId = $x.Package.Applications.Application.Id
                if ($appId -is [array]) { $appId = $appId[0] }
            } catch { }
        }
        if (-not $appId) { $appId = 'App' }
        $aumid = "$($p.FamilyName)!$appId"
        try {
            Start-Process ('shell:AppsFolder\' + $aumid)
            Write-C "  已启动：$aumid" 'Green'
            return
        } catch { }
    }

    $exe = @('ChatGPT.exe', 'Codex.exe') | ForEach-Object { Join-Path $p.AppDir $_ } |
           Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($exe) {
        Start-Process $exe
        Write-C "  已启动：$exe" 'Green'
    } else {
        Write-C '  [X] 未找到可执行文件。' 'Red'
    }
}

function Invoke-Settings {
    while ($true) {
        $cfg = Get-Cfg
        Write-Host ''
        Write-C '  === 设置 ====================================================' 'Cyan'
        Write-C ("    1) 应用安装路径 : " + $(if ($cfg.appPath) { $cfg.appPath } else { '(自动检测)' })) 'White'
        Write-C ("    2) 网络代理     : " + $(if ($cfg.proxy) { $cfg.proxy } else { '(不使用)' })) 'White'
        Write-C ("    3) 横幅样式     : $($cfg.banner)   [auto|full|compact]") 'White'
        Write-C ("    4) 自动备份     : $($cfg.autoBackup)") 'White'
        Write-C '    0) 返回' 'White'
        Write-Host ''
        $c = Read-Host '  选择'
        switch ($c) {
            '1' {
                $v = Read-Host '  输入 app 目录（含 resources\app.asar），留空=自动检测'
                $cfg.appPath = "$v".Trim()
                Save-Cfg $cfg
                if ($cfg.appPath) {
                    if (Test-Path -LiteralPath (Join-Path $cfg.appPath 'resources\app.asar')) { Write-C '  已保存，路径有效。' 'Green' }
                    else { Write-C '  [!] 已保存，但该路径下没有 resources\app.asar。' 'Yellow' }
                } else { Write-C '  已清空，改回自动检测。' 'Gray' }
            }
            '2' {
                $v = Read-Host '  输入代理，如 http://127.0.0.1:7890，留空=不使用'
                $cfg.proxy = "$v".Trim()
                Save-Cfg $cfg
                Write-C '  已保存。' 'Green'
            }
            '3' {
                $v = Read-Host '  输入 auto / full / compact'
                $v = "$v".Trim().ToLower()
                if (@('auto', 'full', 'compact') -contains $v) { $cfg.banner = $v; Save-Cfg $cfg; Write-C '  已保存。' 'Green' }
                else { Write-C '  取值无效。' 'Red' }
            }
            '4' {
                $cfg.autoBackup = -not $cfg.autoBackup
                Save-Cfg $cfg
                Write-C "  自动备份 = $($cfg.autoBackup)" 'Green'
            }
            '0' { return }
            default { Write-C '  无效选择。' 'Red' }
        }
    }
}

# ---------------------------------------------------------------- 主循环
function Show-Menu {
    $CW = Get-ContentWidth
    $bar = '  +' + ('-' * ($CW - 4)) + '+'
    Write-Host ''
    Write-C $bar 'DarkGray'
    $pairs = @(
        @('[1] 一键汉化 / 修复', '[2] 环境体检报告'),
        @('[3] 切换界面语言', '[4] 还原英文设置'),
        @('[5] 启动 ChatGPT / Codex', '[6] 清理副产物'),
        @('[7] 设置', '[8] 网络 / 代理检测'),
        @('[Q] 退出', '[R] 刷新面板')
    )
    $colW = [int](($CW - 5) / 2)
    $colW2 = ($CW - 5) - $colW
    foreach ($p in $pairs) {
        Write-CN '  | ' 'DarkGray'
        Write-CN (PadR $p[0] $colW) 'White'
        Write-CN (PadR $p[1] $colW2) 'Gray'
        Write-C '|' 'DarkGray'
    }
    Write-C $bar 'DarkGray'
}

function Start-Menu {
    if (-not (Test-Interactive)) {
        Write-C '  未检测到交互式终端，改为输出一次体检报告。' 'Yellow'
        Invoke-Check
        return
    }
    while ($true) {
        Clear-Host
        try { $Host.UI.RawUI.WindowTitle = "$($script:AppName)  $($script:Version)" } catch { }
        Show-Banner
        Show-Panel
        Show-Menu
        Write-Host ''
        $c = Read-Host '  请选择'
        Write-Host ''
        switch ("$c".Trim().ToLower()) {
            '1' { Invoke-Apply (Resolve-Language ((Get-Cfg).language)) }
            '2' { Invoke-Check }
            '3' { Invoke-Languages '' }
            '4' { Invoke-Restore }
            '5' { Invoke-Launch }
            '6' { Invoke-Clean }
            '7' { Invoke-Settings }
            '8' { Invoke-Net }
            'r' { Get-AppProbe -Refresh | Out-Null; continue }
            'q' { return }
            '' { continue }
            default { Write-C '  无效选择，请输入 1-8 / R / Q。' 'Red' }
        }
        Write-Host ''
        Write-C '  按回车返回主菜单…' 'DarkGray'
        [void](Read-Host)
    }
}

# ---------------------------------------------------------------- 入口
try {
    switch ($Action) {
        'menu'      { Start-Menu }
        'report'    { Clear-Host; Show-Banner; Show-Panel; Show-Menu }
        'check'     { Invoke-Check }
        'apply'     {
            $l = if ($Language) { Resolve-Language $Language } else { (Get-Cfg).language }
            Invoke-Apply $l
        }
        'restore'   { Invoke-Restore }
        'languages' { Invoke-Languages $Language }
        'clean'     { Invoke-Clean -Force:$Yes }
        'net'       { Invoke-Net }
        'launch'    { Invoke-Launch }
    }
} catch {
    Write-Host ''
    Write-C ("  [异常] " + $_.Exception.Message) 'Red'
    Write-C ("  " + $_.InvocationInfo.PositionMessage) 'DarkGray'
}
