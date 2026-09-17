#requires -Version 5.1
<#
  ======================================================================
   睡醒的夜猫子 · Codex 离线汉化 便携版  (v1.0)
   作者：守夜   仓库：https://github.com/QingYu327/Codex-zh-cn-tool
  ======================================================================

  「Codex 一键汉化」的纯离线便携版（随身携带用）：
    · 不联网、不需要代理、不需要 ChatGPT 登录
    · 不改应用任何文件（商店升级不失效）
    · 自动适配 MSIX 重定向路径（打包 / 非打包两种数据位置都能找到）
    · 注入前自动备份，写完自动 CRC 校验，失败立即中止

  用法：
    1) 整个文件夹拷到 U 盘
    2) 目标机器先启动一次 Codex（生成用户数据），再完全退出
    3) 双击 同名 .cmd → 选 [1] 一键离线汉化
    4) 选 [2] 启动应用 → 界面即为中文

  注意：重装 / 重置应用数据会清掉注入缓存（stableID 重新生成）—— 重跑 [1] 即可。
  ======================================================================
#>
param([string]$Action = 'menu')
$ErrorActionPreference = 'Stop'

$script:AppName    = 'Codex 离线汉化 便携版'
$script:Version    = 'v1.0 (基于主工具 v2.1.5)'
$script:Root       = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$script:BackupDir  = Join-Path $script:Root 'backups'
$script:CodexHome  = Join-Path $env:USERPROFILE '.codex'
$script:ConfigToml = Join-Path $script:CodexHome 'config.toml'
$script:CuConfig   = Join-Path $script:CodexHome 'computer-use\config.json'
$script:StatsigKey = 'client-sYWqzCYMRkUg4DqqiZcR5DGTNl2iD7zNJY0HoeDLzxR'

$script:InnerTemplateB64 = 'H4sIAAAAAAAC/41UyW7bMBT8F51tQZKtLbciCdB0SYIeUhRFQdDkk8WaJgUuTtTA/95HSY7SpCl6sjl8M5y36TFqgDpvgGypAxud' `
    + 'ff+xiHiv6F4wwrRqxHYCJe3BzNBjVGZZWqR1Fv5jPERnM7SIjJdABEeQQ0O9dIhZQDqnpifw0GmLr07aBzBWaBWdpSkeqPQQRKVm' `
    + 'FEWs9oYF9auLSxQBRTdBOq0w3hkPx0UkOHF9F2K8BXN1gWHCEg4HwYBsqAX00VBpAekPnRRMONJRg6Ydvjx68IqDhFAFTt4wesSn' `
    + 'BhqxTg/YIyJOhNzTsqrzfFWUeb3KF1FLLfEdH2saXGL2fHcbyBMNQp7Dazvoh4Iyj7L7q4vhMGZN8O2Ghl83Zj0UtKb1KgG2zJOq' `
    + 'Wa5LXizxzXzJOdRZyWhSllWo9kDBYvwnI2S3BQWGYnJIsszQTiwV2NA7TKglfqhkxH9uQouZ3ndU9UQy714VwFGzBUdo151YK/Pt' `
    + '3Uden9P39zefL9Mv+1be3H9CHQ5GHLAOjQDJx0por5zpkfThNvSyC/Q8LtdxUcXZeo3Yxuh77DV5Gp0ozbM4iRO80/ZuRhGKsyJN' `
    + 'wgW6mW+yIq6TKi6TKi1mwbu/6l2P8/1VKI5Rc/SEn7dG45/ZlXqBa3uCZgnEDm/afHb1wue4FYj/apfn19FxbE0YWr4Lo3Qqd1ZX' `
    + 'q2Rdl1keWkUVMTjUJsy2HYWnqRyP061QW4L9D/McJ7jET+AGn909W6PXtA6bSFmP+s7heejjCdtrHhzvhQp+g9FG0jFkXGdOpN4S' `
    + 'OIByJIyV+dPktPP/iJlkn32eJM4UGb4lllDvNFptkNISoXDp8WLacgwukgT5jZeSsBbYzvo9uq3qMl2n6wznIMlwW5I8i46/Aez+' `
    + 'xfUwBQAA'

function PadR([string]$s, [int]$n) {
    $d = $n - (Get-DisplayWidth $s)
    if ($d -lt 1) { $d = 1 }
    $s + (' ' * $d)
}

function Get-ContentWidth {
    $w = Get-ConWidth
    $c = $w - 8
    if ($c -gt 92) { $c = 92 }
    if ($c -lt 48) { $c = 48 }
    $c
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

function Test-Interactive {
    try { if ([Console]::IsInputRedirected) { return $false } } catch { }
    $true
}

function Copy-FileTreeEfs([string]$Source, [string]$Dest) {
    # EFS 安全递归复制：读出明文 -> 写成新文件。
    # MSIX 的 LocalCache 整棵树带 FILE_ATTRIBUTE_ENCRYPTED，Copy-Item 复制必报
    # "The specified file could not be encrypted."（Win32 6000，本机实测）；
    # robocopy /COPYALL 会带 EFS 属性（需管理员，exit 16）。逐字节读写不走加密语义，最稳。
    # 返回 $true 表示所有文件已复制且长度与源一致。
    if (-not (Test-Path -LiteralPath $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
    $srcLen = $Source.TrimEnd([char]92).Length
    $ok = $true; $n = 0
    foreach ($f in @(Get-ChildItem -LiteralPath $Source -File -Force -Recurse -ErrorAction SilentlyContinue)) {
        $rel = $f.FullName.Substring($srcLen).TrimStart([char]92)
        $target = Join-Path $Dest $rel
        $tdir = Split-Path -Parent $target
        if ($tdir -and -not (Test-Path -LiteralPath $tdir)) { New-Item -ItemType Directory -Path $tdir -Force | Out-Null }
        try {
            if ($f.Length -eq 0) {
                [System.IO.File]::WriteAllBytes($target, (New-Object byte[] 0))
            } else {
                $bytes = Read-FileBytes $f.FullName
                if ($null -eq $bytes) { $ok = $false; continue }
                [System.IO.File]::WriteAllBytes($target, $bytes)
            }
            if ([System.IO.File]::ReadAllBytes($target).Length -ne $f.Length) { $ok = $false }
            $n++
        } catch { $ok = $false }
    }
    return ($ok -and $n -gt 0)
}

function Copy-FileTree {
    # MSIX 商店版应用的数据文件普遍带 EFS 加密属性（FILE_ATTRIBUTE_ENCRYPTED），
    # 用 Copy-Item 复制会报 "The specified file could not be encrypted."(Win32 6000)。
    # robocopy 不走加密语义，复制正常，所以这里一律走 robocopy。
    # 返回 $true 表示成功（robocopy 退出码 0-7 均视为成功）。
    param([string]$Source, [string]$Dest, [string]$Exclude = 'LOCK', [switch]$Mirror)
    if (-not (Test-Path -LiteralPath $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
    $rb = Join-Path $env:SystemRoot 'System32\robocopy.exe'
    if (Test-Path -LiteralPath $rb) {
        $rbArgs = @($Source, $Dest)
        if ($Mirror) { $rbArgs += '/MIR' } else { $rbArgs += '/E' }
        if ($Exclude) { $rbArgs += '/XF'; $rbArgs += $Exclude }
        $rbArgs += @('/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:1', '/W:1')
        & $rb @rbArgs | Out-Null
        if ($LASTEXITCODE -lt 8) { return $true }
        return $false
    }
    # 极端情况下没有 robocopy：退回 Copy-Item（未加密的文件仍可用）
    try {
        foreach ($it in @(Get-ChildItem -LiteralPath $Source -Force -ErrorAction Stop)) {
            if ($Exclude -and $it.Name -eq $Exclude) { continue }
            Copy-Item -LiteralPath $it.FullName -Destination $Dest -Force -Recurse -ErrorAction Stop
        }
        return $true
    } catch { return $false }
}

function Get-WebProfileRoots {
    # Electron 用户数据根目录候选。MSIX 商店版会被虚拟化到 Packages\<PFN>\LocalCache\Roaming 下。
    $out = New-Object System.Collections.Generic.List[string]
    $appNames = @('Codex', 'ChatGPT', 'OpenAI Codex', 'OpenAI')
    try {
        foreach ($pk in @(Get-AppxPackage -ErrorAction SilentlyContinue |
                          Where-Object { $_.Name -like 'OpenAI.*' -or $_.Name -like '*Codex*' -or $_.Name -like '*ChatGPT*' })) {
            foreach ($an in $appNames) {
                $out.Add((Join-Path $env:LOCALAPPDATA ('Packages\' + $pk.PackageFamilyName + '\LocalCache\Roaming\' + $an)))
            }
        }
    } catch { }
    foreach ($an in $appNames) { $out.Add((Join-Path $env:APPDATA $an)) }
    @($out | Select-Object -Unique | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
}

function Find-ProfileRoot {
    # 返回真正存放 web profile 的那一层（…\<App>\web\<profile>）
    foreach ($root in Get-WebProfileRoots) {
        $web = Join-Path $root 'web'
        if (-not (Test-Path -LiteralPath $web)) { continue }
        foreach ($prof in @(Get-ChildItem -LiteralPath $web -Directory -Force -ErrorAction SilentlyContinue)) {
            if (Test-Path -LiteralPath (Join-Path $prof.FullName 'Default\Local Storage')) {
                return $prof.FullName
            }
        }
    }
    $null
}

function Get-StorageLevelDb([string]$profileRoot) {
    if ($profileRoot) {
        $p = Join-Path $profileRoot 'Default\Local Storage\leveldb'
        if (Test-Path -LiteralPath $p) { return $p }
    }
    $pr = Find-ProfileRoot
    if ($pr) { return (Join-Path $pr 'Default\Local Storage\leveldb') }
    $null
}

function Get-SystemProxy {
    # 读取 Windows 系统代理（WinINET）。应用是 Electron/Chromium，网络栈走的就是它。
    $r = [ordered]@{ Enabled = $false; Server = ''; AutoConfig = ''; Uri = ''; Note = '' }
    try {
        $k = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction Stop
        $pe = $null; $sv = ''; $ac = ''
        if ($k.PSObject.Properties['ProxyEnable']) { $pe = $k.ProxyEnable }
        if ($k.PSObject.Properties['ProxyServer']) { $sv = "$($k.ProxyServer)" }
        if ($k.PSObject.Properties['AutoConfigURL']) { $ac = "$($k.AutoConfigURL)" }
        if ($null -ne $pe -and [int]$pe -eq 1 -and $sv) { $r.Enabled = $true; $r.Server = $sv }
        if ($ac) { $r.AutoConfig = $ac }
    } catch { $r.Note = "读取系统代理设置失败：$($_.Exception.Message)" }

    if ($r.Server) {
        $https = ''; $plain = ''
        foreach ($part in ($r.Server -split ';')) {
            $p2 = "$part".Trim()
            if ($p2 -match '^https\s*=\s*(.+)$') { $https = $Matches[1].Trim() }
            elseif ($p2 -match '^http\s*=\s*(.+)$') { $plain = $Matches[1].Trim() }
            elseif ($p2 -and $p2 -notmatch '=') { $plain = $p2 }
        }
        $pick = if ($https) { $https } else { $plain }
        if ($pick) {
            if ($pick -notmatch '://') { $pick = 'http://' + $pick }
            $r.Uri = $pick
        }
    }
    [pscustomobject]$r
}

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

function Get-DJB2Hash([string]$Text) {
    # app.asar 内 _DJB2 的逐字复刻：初值 0，t = (t<<5)-t+charCode（即 31*t，不是经典 DJB2 的 33*t！）
    $t = [long]0
    foreach ($ch in $Text.ToCharArray()) { $t = ((($t -shl 5) - $t) + [int]$ch) -band 0xFFFFFFFFL }
    return [uint32]$t
}

function Get-Crc32cBytes([byte[]]$Data) {
    # LevelDB 用的 CRC-32C（Castagnoli），查表实现。
    # 注意：PS 5.1 的 -shr/-shl 会先把 uint32 转 int32（符号扩展），所以全程用 [long] 域运算。
    if (-not $script:Crc32cTable) {
        $tbl = New-Object 'uint32[]' 256
        for ($i = 0; $i -lt 256; $i++) {
            $c = [long]$i
            for ($j = 0; $j -lt 8; $j++) {
                if ($c -band 1) { $c = (($c -shr 1) -bxor 0x82F63B78L) } else { $c = $c -shr 1 }
            }
            $tbl[$i] = [uint32]$c
        }
        $script:Crc32cTable = $tbl
    }
    # 注意：初值必须写 0xFFFFFFFFL（带 L）。PS 会把裸的 0xFFFFFFFF 当 Int32 解析成 -1，
    # 于是 -shr 8 退化成算术右移，整条 CRC 全歪（v2.1.2 的注入失效就是这个一字符的病）。
    $crc = [long]0xFFFFFFFFL
    foreach ($b in $Data) {
        $crc = ($script:Crc32cTable[[int](($crc -bxor $b) -band 0xFF)] -bxor ($crc -shr 8)) -band 0xFFFFFFFFL
    }
    return [uint32](($crc -bxor 0xFFFFFFFFL) -band 0xFFFFFFFFL)
}

function Get-MaskedCrc([uint32]$Crc) {
    # leveldb 对记录 crc 的掩码；同样全程 [long] 域，避免 PS 5.1 的符号扩展陷阱
    $v = [long]$Crc
    $r = (((($v -shr 15) -bor (($v -shl 17) -band 0xFFFFFFFFL)) + 0xA282EAD8L) -band 0xFFFFFFFFL)
    return [uint32]$r
}

function Write-VarintTo([System.IO.MemoryStream]$ms, [int]$Value) {
    $v = $Value
    while ($true) {
        $b = $v -band 0x7F; $v = $v -shr 7
        if ($v) { $ms.WriteByte([byte]($b -bor 0x80)) } else { $ms.WriteByte([byte]$b); break }
    }
}

function Read-LevelDbLogTail([string]$LogPath, [switch]$VerifyCrc) {
    # 扫描 .log 全部记录（含 FIRST/MIDDLE/LAST 分片重组），返回末尾偏移、最大 seq、
    # 以及最后一条 statsig.stable_id 的值（若在 .log 里）。
    # -VerifyCrc：逐条校验 crc32c。leveldb 恢复时会【丢弃 crc 非法的记录】，
    #   所以「结构能解析」不等于「记录真的生效」——自检必须按 crc 判定，
    #   否则写坏了也报成功（v2.1.2 就是这么骗过自检的）。
    $bytes = [System.IO.File]::ReadAllBytes($LogPath)
    $n = $bytes.Length; $pos = 0
    $st = @{ MaxSeq = [uint64]0; Sid = $null; SidSeq = [uint64]0; BadCrc = 0; Checked = 0; EvalCnt = 0 }
    $buf = $null
    $flush = {
        param([byte[]]$Batch, [hashtable]$St)
        if (-not $Batch -or $Batch.Length -lt 12) { return }
        $seq = [BitConverter]::ToUInt64($Batch, 0)
        if ($seq -gt $St.MaxSeq) { $St.MaxSeq = $seq }
        $cnt = [BitConverter]::ToUInt32($Batch, 8)
        $off = 12
        for ($e = 0; $e -lt $cnt -and $off -lt $Batch.Length; $e++) {
            $t = $Batch[$off]; $off++
            $kl = 0; $sh = 0
            while ($true) { $c = $Batch[$off]; $off++; $kl = $kl -bor (($c -band 0x7F) -shl $sh); if (-not ($c -band 0x80)) { break }; $sh += 7 }
            $key = New-Object byte[] $kl
            [Array]::Copy($Batch, $off, $key, 0, $kl); $off += $kl
            if ($t -eq 0) { continue }   # deletion：无 value
            $vl = 0; $sh = 0
            while ($true) { $c = $Batch[$off]; $off++; $vl = $vl -bor (($c -band 0x7F) -shl $sh); if (-not ($c -band 0x80)) { break }; $sh += 7 }
            $val = New-Object byte[] $vl
            [Array]::Copy($Batch, $off, $val, 0, $vl); $off += $vl
            $ks = [Text.Encoding]::ASCII.GetString($key)
            if ($ks -like '*statsig.cached.evaluations.*') { $St.EvalCnt = [int]$St.EvalCnt + 1 }
            if ($ks -like '*statsig.stable_id.685440364' -and $seq -ge $St.SidSeq) {
                $St.SidSeq = $seq
                $St.Sid = [Text.Encoding]::UTF8.GetString($val)
            }
        }
    }
    while ($pos + 7 -le $n) {
        $blkRem = 32768 - ($pos % 32768)
        if ($blkRem -lt 7) { $pos += $blkRem; continue }
        $len = [BitConverter]::ToUInt16($bytes, $pos + 4)
        $typ = $bytes[$pos + 6]
        if ($bytes[$pos] -eq 0 -and $bytes[$pos+1] -eq 0 -and $bytes[$pos+2] -eq 0 -and $bytes[$pos+3] -eq 0 -and $len -eq 0 -and $typ -eq 0) {
            $pos += $blkRem; continue
        }
        if ($pos + 7 + $len -gt $n) { break }
        $body = New-Object byte[] $len
        [Array]::Copy($bytes, $pos + 7, $body, 0, $len)
        if ($VerifyCrc) {
            # 物理记录 = [crc(4)][len(2)][type(1)][data]；crc 覆盖 type 字节 + data
            $st.Checked = [int]$st.Checked + 1
            $hb = New-Object byte[] ($len + 1)
            $hb[0] = [byte]$typ
            [Array]::Copy($body, 0, $hb, 1, $len)
            if ([BitConverter]::ToUInt32($bytes, $pos) -ne (Get-MaskedCrc (Get-Crc32cBytes $hb))) {
                $st.BadCrc = [int]$st.BadCrc + 1
            }
        }
        if     ($typ -eq 1) { & $flush $body $st; $buf = $null }
        elseif ($typ -eq 2) { $buf = $body }
        elseif ($typ -eq 3) { $buf = @($buf) + @($body) }
        elseif ($typ -eq 4) { $buf = @($buf) + @($body); & $flush ([byte[]]$buf) $st; $buf = $null }
        $pos += 7 + $len
    }
    # 注意：这里必须把 BadCrc / Checked / EvalCnt 一并返回。
    # v2.1.3 一开始漏了这三个字段 -> 调用方拿到 $null -> `-eq 0` 不成立 ->
    # 明明写入成功却报「自检未通过」（纯误报）。字段名改动时记得同步这里。
    [pscustomobject]@{
        EndPos      = $pos
        Size        = $n
        MaxSeq      = $st.MaxSeq
        StableIdRaw = $st.Sid
        SidSeq      = $st.SidSeq
        BadCrc      = [int]$st.BadCrc
        Checked     = [int]$st.Checked
        EvalCnt     = [int]$st.EvalCnt
    }
}

function Get-LevelDbStableId([string]$LevelDbDir) {
    # 兜底：目标 .log 里读不到 stable_id 时（被压缩进 .ldb、或日志轮转过），
    # 扫目录下所有 .log，取 seq 最大的那条（应用首次启动会写入一次 stable_id）。
    $best = $null; $bestSeq = [uint64]0
    foreach ($f in @(Get-ChildItem -LiteralPath $LevelDbDir -Filter '*.log' -File -Force -ErrorAction SilentlyContinue)) {
        try {
            $t = Read-LevelDbLogTail -LogPath $f.FullName
            $m = [regex]::Match("$($t.StableIdRaw)", "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
            if ($m.Success -and $t.MaxSeq -ge $bestSeq) { $bestSeq = $t.MaxSeq; $best = $m.Value.ToLowerInvariant() }
        } catch { }
    }
    return $best
}

function Write-LevelDbBatch([string]$LogPath, [int64]$AtOffset, [uint64]$Seq, [byte[][]]$Keys, [byte[][]]$Values) {
    # 构造 WriteBatch（put 条目）并按 leveldb log 格式（32KB 块 + crc32c + 分片）追加
    $ms = New-Object System.IO.MemoryStream
    [void]$ms.Write([BitConverter]::GetBytes([uint64]$Seq), 0, 8)
    [void]$ms.Write([BitConverter]::GetBytes([uint32]$Keys.Count), 0, 4)
    for ($i = 0; $i -lt $Keys.Count; $i++) {
        $ms.WriteByte(1)                              # kTypeValue
        Write-VarintTo $ms $Keys[$i].Length
        [void]$ms.Write($Keys[$i], 0, $Keys[$i].Length)
        Write-VarintTo $ms $Values[$i].Length
        [void]$ms.Write($Values[$i], 0, $Values[$i].Length)
    }
    $batch = $ms.ToArray()

    $fs = [System.IO.File]::Open($LogPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)
    try {
        $fs.Seek($AtOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $maxChunk = 32768 - 7
        $off = 0; $first = $true; $n = $batch.Length
        while ($true) {
            $blkRem = 32768 - ([int]($fs.Position % 32768))
            if ($blkRem -le 7) { $fs.Write((New-Object byte[] $blkRem), 0, $blkRem) }
            $avail = 32768 - ([int]($fs.Position % 32768)) - 7
            if ($avail -gt $maxChunk) { $avail = $maxChunk }
            $take = [Math]::Min($avail, $n - $off)
            if ($take -le 0) { $take = 0 }
            $chunk = New-Object byte[] $take
            [Array]::Copy($batch, $off, $chunk, 0, $take); $off += $take
            if     ($first -and $off -ge $n) { $typ = 1 }   # FULL
            elseif ($first)                  { $typ = 2 }   # FIRST
            elseif ($off -ge $n)             { $typ = 4 }   # LAST
            else                             { $typ = 3 }   # MIDDLE
            $body = New-Object byte[] ($take + 1)
            $body[0] = $typ
            [Array]::Copy($chunk, 0, $body, 1, $take)
            $crc = Get-MaskedCrc (Get-Crc32cBytes $body)
            $hdr = New-Object byte[] 7
            [void][BitConverter]::GetBytes([uint32]$crc).CopyTo($hdr, 0)
            [void][BitConverter]::GetBytes([uint16]$take).CopyTo($hdr, 4)
            $hdr[6] = $typ
            $fs.Write($hdr, 0, 7)
            if ($take -gt 0) { $fs.Write($chunk, 0, $take) }
            $first = $false
            if ($off -ge $n) { break }
        }
        $fs.Flush()
    } finally { $fs.Dispose() }
}

function Invoke-OfflineInject {
    param([switch]$NoPrompt)
    Write-Host ''

    # ---- 内部 CRC32C 自检（标准测试向量 crc32c("123456789") = 0xE3069283）----
    # 写进 leveldb 的记录，crc 一旦算错，leveldb 恢复时会【静默丢弃整条记录】，
    # 表现为「脚本报成功、界面照样英文」。这里先验算法本身；用字符串比较，
    # 彻底避开 PS 十六进制字面量的符号解析坑。
    $crcProbe = '{0:X8}' -f (Get-Crc32cBytes ([Text.Encoding]::ASCII.GetBytes('123456789')))
    if ($crcProbe -ne 'E3069283') {
        Write-C ("  [X] 内部 CRC32C 自检失败（算出 $crcProbe，应为 E3069283），" ) 'Red'
        Write-C '      为免写出 leveldb 无法识别的坏记录，已拒绝执行。' 'Red'
        return
    }

    Write-C '  === 离线开关注入（菜单 [7] · 纯本地，全程不联网）================' 'Cyan'
    Write-C '  面向「国内无代理 / 离线」的机器：不联网，直接把汉化开关' 'Gray'
    Write-C '  （enable_i18n = true）写进应用本地缓存。原理：缓存键只由本机' 'Gray'
    Write-C '  stableID 决定，本工具读出 / 写入 stableID 后现场计算键名。' 'Gray'

    $ldb = Get-StorageLevelDb (Find-ProfileRoot)
    if (-not $ldb -or -not (Test-Path -LiteralPath $ldb)) {
        Write-C '  [X] 未找到应用的 Local Storage（先启动一次应用再执行本功能）。' 'Red'
        return
    }
    Write-C ("    · 缓存目录        : $ldb") 'Gray'

    # 应用必须退出：运行中写 leveldb 会被应用的内存态覆盖
    $running = @(Get-Process -Name 'ChatGPT' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        if ($NoPrompt -or -not (Test-Interactive)) {
            Write-C '  [X] 应用正在运行，请先完全退出（托盘图标右键 -> 退出）再执行。' 'Red'
            return
        }
        Write-C '  [!] 检测到应用正在运行，请先完全退出（窗口关闭 + 托盘图标右键 -> 退出）。' 'Yellow'
        Read-Host '  退出完成后按回车继续'
        $running = @(Get-Process -Name 'ChatGPT' -ErrorAction SilentlyContinue)
        if ($running.Count -gt 0) { Write-C '  [X] 应用仍在运行，已取消。' 'Red'; return }
    }

    # 写入权限预检：
    # 实测：应用自己创建的缓存文件（MSIX LocalCache 里的 EFS「应用级保护」加密文件）对普通进程
    # 呈「可读不可写」——访问被拒绝，ACL/属性里看不出异常，提权也无效。
    # 但同目录的**目录本身**可重命名、也可新建，新建出来的文件就是可写的。
    # 所以检测到写不进去时，自动切到「整目录换血」方案（见下方 if ($rebuild) 分支），无需管理员。
    $log = @(Get-ChildItem -LiteralPath $ldb -Filter '*.log' | Sort-Object LastWriteTime -Descending)[0]
    if (-not $log) { Write-C '  [X] 未找到 .log 文件。' 'Red'; return }
    $writeOk = $false
    try {
        $fs = [System.IO.File]::Open($log.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
        $fs.Close(); $writeOk = $true
    } catch { }
    $rebuild = $false
    if (-not $writeOk) {
        Write-Host ''
        Write-C "  [!] 缓存文件无法直接写入（访问被拒绝）：$($log.Name)" 'Yellow'
        Write-C '      这是应用数据的「应用级保护」EFS 加密特性：普通进程可读不可写，' 'Gray'
        Write-C '      提权也无效（不是权限标签问题）。' 'Gray'
        Write-C '      -> 自动改用「整目录换血」：原目录整体改名留档，新建同名目录，' 'Gray'
        Write-C '         把缓存逐字节复制过去（新文件由本工具创建 -> 可写），在副本上注入。' 'Gray'
        Write-C '         原目录原样保留，随时可还原。' 'Gray'
        if (-not $NoPrompt -and (Test-Interactive)) {
            Write-Host ''
            $c = Read-Host '  继续用「整目录换血」方式注入？(Y/n)'
            if ($c -match '^[nN]') { Write-C '  已取消。' 'Gray'; return }
        }
        $rebuild = $true
    }
    if (-not $rebuild) { Write-C ("    · 目标缓存        : $($log.Name)（可写）") 'Green' }

    # 备份（必做，失败即中止）
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dst = Join-Path $script:BackupDir ("leveldb.$stamp")
    if ($rebuild) {
        # 换血模式的"备份"就是原目录本身：整体改名留档，内容原样不动，最强留档。
        $keepName = 'leveldb.orig-' + $stamp
        $keep = Join-Path (Split-Path -Parent $ldb) $keepName
        try {
            if (Test-Path -LiteralPath $keep) { throw "留档目录已存在：$keep" }
            Rename-Item -LiteralPath $ldb -NewName $keepName -ErrorAction Stop
            Write-C ("    · 原目录改名留档  : $keep") 'Green'
            New-Item -ItemType Directory -Path $ldb -Force -ErrorAction Stop | Out-Null
            if (-not (Copy-FileTreeEfs -Source $keep -Dest $ldb)) { throw '逐字节复制未全部成功' }
            $n = @(Get-ChildItem -LiteralPath $ldb -File -Force -Recurse -ErrorAction SilentlyContinue).Count
            if ($n -lt 3) { throw "新目录文件数异常（$n）" }
            Write-C ("    · 已重建缓存目录  : $ldb （$n 个文件，本工具创建 -> 可写）") 'Green'
            $log = @(Get-ChildItem -LiteralPath $ldb -Filter '*.log' | Sort-Object LastWriteTime -Descending)[0]
            if (-not $log) { throw '新目录中没有 .log 文件' }
            $chk = $false
            try { $fs = [System.IO.File]::Open($log.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite); $fs.Close(); $chk = $true } catch { }
            if (-not $chk) { throw '新目录里的 .log 仍不可写' }
        } catch {
            Write-C "  [X] 换血失败：$($_.Exception.Message)" 'Red'
            Write-C '      正在回滚到原目录…' 'Gray'
            try {
                if ((Test-Path -LiteralPath $ldb) -and (Test-Path -LiteralPath $keep)) { Remove-Item -LiteralPath $ldb -Recurse -Force -ErrorAction SilentlyContinue }
                if ((Test-Path -LiteralPath $keep) -and -not (Test-Path -LiteralPath $ldb)) { Rename-Item -LiteralPath $keep -NewName (Split-Path -Leaf $ldb) -ErrorAction SilentlyContinue }
                Write-C ('      回滚完成：' + $(if (Test-Path -LiteralPath $ldb) { '原目录已还原' } else { '请手工把 ' + $keep + ' 改回 leveldb' })) 'Yellow'
            } catch { Write-C "      回滚也失败：$($_.Exception.Message)（原目录仍在 $keep）" 'Red' }
            return
        }
    } else {
    try {
        if (-not (Test-Path -LiteralPath $script:BackupDir)) { New-Item -ItemType Directory -Path $script:BackupDir | Out-Null }
        # MSIX 的 LocalCache 树带 EFS 加密属性：Copy-Item 必报 Win32 6000（本机实测过），
        # 所以走逐字节复制；万一失败退 robocopy；仍不行就中止（绝不允许无备份写入）。
        $copied = Copy-FileTreeEfs -Source $ldb -Dest $dst
        $n = @(Get-ChildItem -LiteralPath $dst -File -Force -Recurse -ErrorAction SilentlyContinue).Count
        if (-not $copied -or $n -lt 3) {
            if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force -ErrorAction SilentlyContinue }
            $copied = Copy-FileTree -Source $ldb -Dest $dst
            $n = @(Get-ChildItem -LiteralPath $dst -File -Force -Recurse -ErrorAction SilentlyContinue).Count
        }
        if (-not $copied -or $n -lt 3) { throw "备份不完整（$n 个文件）——可能是杀软拦截或权限不足" }
        Write-C ("    · 已备份到        : $dst （$n 个文件）") 'Green'
    } catch {
        Write-C "  [X] 备份失败，已中止注入：$($_.Exception.Message)" 'Red'
        return
    }
    }

    # 选最新的 .log 并解析尾部（$log 已在写入预检时取好）
    if (-not $log) { Write-C '  [X] 未找到 .log 文件。' 'Red'; return }
    $tail = Read-LevelDbLogTail -LogPath $log.FullName
    if ($tail.EndPos -ne $tail.Size) {
        Write-C "  [X] .log 尾部无法解析（$($tail.EndPos) / $($tail.Size)），已中止。" 'Red'
        return
    }
    Write-C ("    · 写入目标        : $($log.Name)（现有 $($tail.MaxSeq) 号之前的记录，最大 seq $($tail.MaxSeq)）") 'Gray'

    # stableID：必须用「应用自己的」那个（应用首次启动会生成并写进缓存）。
    # 坑：解析器返回的是原始 value（形如 \x01"uuid"），必须从中抠出 UUID，
    #     否则整串匹配失败 -> 误判"没有 stableID" -> 凭空造一个 -> 缓存键必然对不上。
    $sid = $null
    $m = [regex]::Match("$($tail.StableIdRaw)", "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
    if ($m.Success) { $sid = $m.Value.ToLowerInvariant() }
    if (-not $sid) { $sid = Get-LevelDbStableId -LevelDbDir $ldb }
    if (-not $sid) {
        Write-Host ''
        Write-C '  [X] 读不到应用自己的 stableID，已中止 —— 凭空造一个的键一定对不上。' 'Red'
        Write-C '      缓存键 = DJB2("…stableID-<本机sid>…")，只有拿到应用真正在用的 sid 才算得准。' 'Gray'
        Write-C '      解决：先启动一次应用（离线也行，界面会是英文），完全退出后再执行本功能；' 'Yellow'
        Write-C '            应用首次启动会把 stableID 写进缓存，那时就读得到了。' 'Yellow'
        return
    }
    Write-C ("    · 本机 stableID   : $sid  （应用自己的，键按它算）") 'Gray'
    $putStable = $true   # 顺手把 stable_id 也写成同一个值，保证与应用自洽

    # 键名现场计算。主公式（在 app.asar 里逐字核对过）：
    #     DJB2("uid:|cids:source_surface_stable_id-<sid>,stableID-<sid>|k:<sdkKey>")
    # 另外再写 3 个变体键作保险：uid 取空还是 ua-<sid>、cids 是否含
    # source_surface_stable_id，在不同 SDK 版本 / 不同登录态下可能不同。
    # 多写几份键不影响应用任何逻辑，纯冗余兜底（应用只按自己那个键取）。
    $cidsFull = "source_surface_stable_id-$sid,stableID-$sid"
    $cidsSolo = "stableID-$sid"
    $combo = @(
        @('',         $cidsFull),
        @("ua-$sid",  $cidsFull),
        @('',         $cidsSolo),
        @("ua-$sid",  $cidsSolo)
    )
    $evalSuffix = Get-DJB2Hash ("uid:$($combo[0][0])|cids:$($combo[0][1])|k:$($script:StatsigKey)")
    Write-C ("    · 缓存键（现场算）: statsig.cached.evaluations.$evalSuffix") 'Gray'
    Write-C ("      另写 " + ($combo.Count - 1) + " 个变体键名兜底（uid / cids 写法差异）") 'DarkGray'

    # payload：内嵌模板解压 -> 套上外层（stableID 用本机的）
    $inner = $null
    try {
        $gz = [Convert]::FromBase64String($script:InnerTemplateB64)
        $msIn = New-Object System.IO.MemoryStream(, $gz)
        $gzs = New-Object System.IO.Compression.GzipStream($msIn, [System.IO.Compression.CompressionMode]::Decompress)
        $msOut = New-Object System.IO.MemoryStream
        $gzs.CopyTo($msOut); $gzs.Dispose()
        $inner = [Text.Encoding]::UTF8.GetString($msOut.ToArray())
    # 防御（v2.1.5）：statsig 对这几个字段的类型有硬性要求 ——
    # feature_gates / dynamic_configs 必须是【数组】，写成对象会让 SDK 在
    # _seedLiveValues 里抛 "dynamic_configs is not iterable"，导致整个界面渲染成空页；
    # live_entity_names 存在则触发同一段代码路径，去掉它 SDK 会直接走安全出口。
    # 这里再兜一次底，模板将来被改错也不会打崩应用。
    $inner = [regex]::Replace($inner, '"feature_gates"\s*:\s*\{\s*\}', '"feature_gates":[]')
    $inner = [regex]::Replace($inner, '"dynamic_configs"\s*:\s*\{\s*\}', '"dynamic_configs":[]')
    $inner = [regex]::Replace($inner, ',\s*"live_entity_names"\s*:\s*\{[^{}]*\}', '')
    } catch {
        Write-C "  [X] 内置模板解压失败：$($_.Exception.Message)" 'Red'
        return
    }
    $esc = $inner.Replace('\', '\\').Replace('"', '\"')
    $ms = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $outer = '{"source":"Network","data":"' + $esc + '","receivedAt":' + $ms + ',"stableID":"' + $sid + '"}'

    $kp = [Text.Encoding]::ASCII.GetBytes("_app://-$([char]0)$([char]1)")
    $keys = New-Object 'System.Collections.Generic.List[byte[]]'
    $vals = New-Object 'System.Collections.Generic.List[byte[]]'
    if ($putStable) {
        $keys.Add([byte[]]($kp + [Text.Encoding]::ASCII.GetBytes('statsig.stable_id.685440364')))
        $vals.Add([byte[]](@(0x01) + [Text.Encoding]::ASCII.GetBytes('"' + $sid + '"')))
    }
    foreach ($cb in $combo) {
        $sfx = Get-DJB2Hash ("uid:$($cb[0])|cids:$($cb[1])|k:$($script:StatsigKey)")
        $keys.Add([byte[]]($kp + [Text.Encoding]::ASCII.GetBytes("statsig.cached.evaluations.$sfx")))
        $vals.Add([byte[]](@(0x01) + [Text.Encoding]::ASCII.GetBytes($outer)))
    }

    Write-C ("    · 写入内容        : 开关缓存 " + $outer.Length + " 字节 x " + $combo.Count + " 个键名（含 enable_i18n = true）") 'Gray'
    try {
        Write-LevelDbBatch -LogPath $log.FullName -AtOffset $tail.EndPos -Seq ([uint64]($tail.MaxSeq + 1)) -Keys $keys.ToArray() -Values $vals.ToArray()
    } catch {
        Write-C "  [X] 写入失败：$($_.Exception.Message)" 'Red'
        if ("$($_.Exception.Message)" -match '拒绝|denied') {
            Write-C '      访问被拒绝通常是权限问题：请以管理员身份重新运行本工具再试。' 'Yellow'
        }
        Write-C "      备份在 $dst ，可直接还原。" 'Gray'
        return
    }

    # 自校验：重读 .log，确认写入的记录「真能被 leveldb 恢复」——
    # 结构可解析 **且** crc32c 合法 **且** 缓存条目确实在里面。
    # （旧版只看结构：crc 写错也照样报成功，应用却完全读不到 —— v2.1.2 就是这么骗过自检的。）
    $tail2 = Read-LevelDbLogTail -LogPath $log.FullName -VerifyCrc
    $sidOk = [bool]($tail2.StableIdRaw -and $tail2.StableIdRaw.Contains($sid))
    $ok = ($tail2.EndPos -eq $tail2.Size) -and ($tail2.BadCrc -eq 0) -and ($tail2.Checked -ge 1) -and ($tail2.EvalCnt -ge 1) -and $sidOk
    if ($ok) {
        Write-C ("  [OK] 注入完成，自检通过（已校验 crc 的记录 " + $tail2.Checked + " 条 / 非法 0 条）。") 'Green'
        Write-C ("       缓存条目 " + $tail2.EvalCnt + " 条已就位，启动 / 重启应用即可看到中文界面 —— 全程无需代理。") 'White'
        Write-C '       （应用下次能联网时会照常向服务端刷新，结果一致，不影响。）' 'DarkGray'
        Write-C '       · 顺带一提：若「文件 → 打开文件夹」等菜单项不见了，那是【未登录 ChatGPT】' 'DarkGray'
        Write-C '         导致的（该菜单项的 requiredAccess 依赖账号套餐），与本次汉化无关；' 'DarkGray'
        Write-C '         登录成功后会自动回来。' 'DarkGray'
    } else {
        Write-C ("  [X] 自检未通过：crc 非法的记录 " + $tail2.BadCrc + " 条 / 已校验 " + $tail2.Checked + " 条，") 'Red'
        Write-C ("      尾部解析 " + $tail2.EndPos + " / " + $tail2.Size + "，缓存条目 " + $tail2.EvalCnt + " 条。") 'Red'
        Write-C '      多半是写入被截断或被杀软改写；请从备份还原后重试。' 'Yellow'
        return
    }

    if (-not $NoPrompt -and (Test-Interactive)) {
        $c = Read-Host '  现在启动应用验证？(Y/n)'
        if ($c -notmatch '^[nN]') {
            Invoke-Launch
            Write-C '  等几秒看界面是否变中文。' 'White'
        }
    }
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


# ---------------------------------------------------------------- 状态检查
function Show-Status {
    Write-Host ''
    Write-C '  === 状态 ===' 'Cyan'
    $ok1 = $false
    if (Test-Path -LiteralPath $script:ConfigToml) {
        $c = Get-Content -LiteralPath $script:ConfigToml -Raw -Encoding UTF8
        $ok1 = ($c -match 'localeOverride\s*=\s*"zh-CN"')
    }
    Write-C ('    条件一 localeOverride = zh-CN : ' + $(if ($ok1) { '已写入' } else { '未写入（选 [1] 一键汉化）' })) $(if ($ok1) { 'Green' } else { 'Yellow' })
    $ldb = Get-StorageLevelDb (Find-ProfileRoot)
    $ok2 = $false
    if ($ldb -and (Test-Path -LiteralPath $ldb)) {
        $log = @(Get-ChildItem -LiteralPath $ldb -Filter '*.log' | Sort-Object LastWriteTime -Descending)[0]
        if ($log) {
            $t = Read-LevelDbLogTail -LogPath $log.FullName -VerifyCrc
            $ok2 = ($t.EvalCnt -ge 1) -and ($t.BadCrc -eq 0)
        }
    }
    Write-C ('    条件二 开关缓存已注入        : ' + $(if ($ok2) { '已注入' } else { '未注入（选 [1] 一键汉化）' })) $(if ($ok2) { 'Green' } else { 'Yellow' })
    $rt = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
    $hasRt = (Test-Path -LiteralPath $rt) -and (@(Get-ChildItem -LiteralPath $rt -Directory -ErrorAction SilentlyContinue).Count -gt 0)
    Write-C ('    CLI 运行时（bin 下的哈希目录）: ' + $(if ($hasRt) { '已就绪' } else { '未安装（先启动一次应用自动下载）' })) $(if ($hasRt) { 'Green' } else { 'Yellow' })
    $app = Get-AppxPackage -Name OpenAI.Codex -ErrorAction SilentlyContinue
    Write-C ('    应用版本                      : ' + $(if ($app) { $app.Version + '  Status=' + $app.Status } else { '未安装' })) 'Gray'
    Write-Host ''
    $msg = if ($ok1 -and $ok2) { '两个条件都已就位 —— 启动应用即为中文' } else { '还差条件，按上面提示操作' }
    Write-C ('    结论：' + $msg) 'White'
}

# ---------------------------------------------------------------- 一键还原英文
function Invoke-RestoreEn {
    Write-C '  === 还原英文设置 ===' 'Cyan'
    if (Test-Path -LiteralPath $script:ConfigToml) {
        Set-TomlLocale $script:ConfigToml '' -Remove
        Write-C '    已移除 localeOverride（条件一撤销）' 'Green'
    } else { Write-C '    config.toml 不存在。' 'Gray' }
    $cu = Set-ComputerUseLocale '' -Reset
    if ($cu -eq 'reset') { Write-C '    computer-use/config.json 已还原' 'Green' }
    Write-C '  注入的开关缓存保留在缓存里（不影响英文显示）；如需彻底清除请重置应用数据。' 'Gray'
}

# ---------------------------------------------------------------- 菜单
function Show-Menu {
    Write-Host ''
    Write-C '  +----------------------------------------------------------+' 'DarkGray'
    Write-C '  |  Codex 离线汉化 便携版  (完全离线 / 无需登录)                 |' 'White'
    Write-C '  +----------------------------------------------------------+' 'DarkGray'
    Write-C '    [1] 一键离线汉化   （写语言 + 注入开关，全程不联网）' 'White'
    Write-C '    [2] 启动 Codex 应用' 'Gray'
    Write-C '    [3] 还原英文设置   （撤销条件一）' 'Gray'
    Write-C '    [4] 状态检查' 'Gray'
    Write-C '    [0] 退出' 'Gray'
    Write-Host ''
}

function Start-Menu {
    while ($true) {
        Clear-Host
        Write-Host ''
        Write-C ($script:AppName + '   ' + $script:Version) 'White'
        Show-Status
        Show-Menu
        $c = Read-Host '  请选择'
        switch ("$c".Trim()) {
            '1' { Invoke-OfflineInject }
            '2' { Invoke-Launch }
            '3' { Invoke-RestoreEn }
            '4' { Show-Status | Out-Null }
            '0' { return }
            '' { }
        }
        if ("$c".Trim() -ne '0') {
            Write-Host ''
            Read-Host '  按回车返回菜单'
        }
    }
}

# ---------------------------------------------------------------- 入口
try {
    switch ($Action.ToLower()) {
        'menu'    { Start-Menu }
        'apply'   { Invoke-OfflineInject -NoPrompt }
        'launch'  { Invoke-Launch }
        'restore' { Invoke-RestoreEn }
        'status'  { Show-Status | Out-Null }
        default   { Start-Menu }
    }
} catch {
    Write-Host ''
    Write-C ('  [异常] ' + $_.Exception.Message) 'Red'
    Write-C ('  ' + $_.InvocationInfo.PositionMessage) 'DarkGray'
}
