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
             不再改动任何应用文件，升级后依然有效。

  【v2.1.0 必读】界面变中文需要两个条件同时成立：
    条件一  ~/.codex/config.toml 里 [desktop] localeOverride = "zh-CN"
            <- 本工具负责，纯本地即可完成。
    条件二  应用远程开关 enable_i18n = true
            <- 由应用在启动时向 https://ab.chatgpt.com/v1/initialize 拉取。

  已逐字节核实的事实（v2.1.0 再次修正了 v2.0.0 的一个错误结论）：
    · 语言包 100% 内置：app.asar 里两套资源一一对应，各 64 种语言 ——
      原生菜单 native-menu-locales/<locale>.json（zh-CN 共 196 键）与
      前端 chunk webview/assets/<locale>-<hash>.js（zh-CN 1,394,280 字节 / 面板显示 1.3 MB）。
      本地相对路径动态 import，从来不需要下载，与代理也无关。
    · 「菜单栏是中文」不等于「界面汉化生效」：原生菜单跟随系统语言，界面文字才受
      enable_i18n 控制 —— 所以会出现「菜单展开是中文、界面全是英文」这种怪象。
    · enable_i18n 在服务端是【无条件下发】(rule_id = default，与账号、设备、百分比
      抽签都无关)。换句话说：应用只要能成功访问上面那个域名一次，界面就会变中文；
      结果落盘缓存后长期有效，之后离线也没关系。
    · 但 ab.chatgpt.com 在中国大陆被 DNS 污染 + TCP 超时（本机实测直连必超时），
      而事件上报用的 api.oaistatsig.com 并没有被墙 —— 于是出现「应用看着能上网、
      开关却永远 false」。联网解法：让应用能走到 ab.chatgpt.com
      （系统代理 / TUN / 全局模式，且代理规则要覆盖该域名），然后重启应用。
    · 缓存键 statsig.cached.evaluations.<hash> 的公式（asar 逐字确认 + 本机复现）：
      DJB2("uid:|cids:source_surface_stable_id-<sid>,stableID-<sid>|k:<sdkKey>")
      —— DJB2 初值是 0，输入只有本机 stableID 一个变量，而 stableID 的存储键
      statsig.stable_id.685440364 的后缀是跨机器常量。
      => v1.2.0「加速包」失败的原因是整目录照搬了别台机器的键（键对不上），
         不是"机制上不可能"。v2.1.0 据此实现【离线开关注入】（v2.1.4 起独立为菜单 [7]）：
         读/写本机 stableID -> 现场算键 -> 按 LevelDB WriteBatch 格式写缓存，
         全程无代理无联网。本机已完整 E2E 实测：删缓存变英文，注入变回中文。
    · 【v2.1.3 修正 · 必看】离线注入曾连着三次「报成功却无效」，根因是脚本内部
      CRC32C 的初值写成了裸的 0xFFFFFFFF —— PowerShell 会把它当 Int32 解析成 -1，
      于是算出的记录 crc 全是错的；而 leveldb 在 Recover 时会【静默丢弃 crc 非法的
      记录】，所以注入其实一条都没生效：应用读到的 stableID 一直是它自己的，
      缓存键自然对不上。修复 + 三道防呆：
        ① 0xFFFFFFFF -> 0xFFFFFFFFL（全脚本唯一漏 L 的一处，其余 6 处本来就带）；
        ② 注入前跑标准测试向量 crc32c("123456789") = 0xE3069283 自检，不过就拒绝写入；
        ③ 注入后按 crc 复读校验（旧版只看结构，坏记录也能"通过自检"）；
        ④ 同一份 payload 改写成 4 个变体键名（uid 空 / ua-<sid> × cids 全量 / 仅
           stableID），不同 SDK 版本或登录态下取值不同时也能命中，纯冗余兜底。

    · 【v2.1.5 修正 · 必看】注入模板里的 `feature_gates` / `dynamic_configs` 必须是
      【数组 []】，`live_entity_names` 必须【删掉】。原模板把它们写成了空对象 {}，
      而 statsig 的 `_seedLiveValues` 会用 for…of 迭代 dynamic_configs ——
      于是抛 `TypeError: e.dynamic_configs is not iterable`，statsig 初始化失败，
      整个 React 应用渲染成空白页（表现为"卡在 logo 闪屏"）。
      已在模板里改正，并在 Invoke-OfflineInject 里加了一道正则兜底。

  【v2.1.4 变更】菜单与体验
    · [7] = 离线注入汉化开关（纯本地，秒级完成，不做任何联网探测）
      [8] = 在线诊断与修复（原来的远程开关自检，需要代理）
      [9] = 网络 / 代理检测     [0] = 设置
      —— 之前 [7] 里混着联网自检，光探测就要等 20 多秒，现已被拆开。
    · 状态面板不再做 TCP 探测（以前每次重绘都白等 2.5 秒超时）。
    · 修掉 v2.1.3 的一个自检误报：Read-LevelDbLogTail 忘了返回 BadCrc/Checked/EvalCnt，
      调用方拿到 $null -> 判断必然失败 -> 写入明明成功却报「自检未通过」。

  【重要 · 别踩】「文件 → 打开文件夹」菜单项消失 ≠ 汉化的副作用
    实测取证（本机日志 + asar 逐字比对）：
      · 该菜单项命令 openFolder 的 requiredAccess 是 codexOrWorkLocal；
      · 主进程的 {codexLocal, workLocal} 来自渲染进程广播的 IPC 消息
        electron-desktop-features-changed 里的 codexLocalAccess / workLocalAccess；
      · 而这两个值出自 Cun()：未登录 / 拿不到账号套餐时返回
        {status:'denied', reason:'missing-account'} -> 菜单项被摘掉；
        登录且套餐属 free/go/plus/prolite/pro 时才 {status:'allowed'}。
      => 即它取决于「是否登录 ChatGPT + 账号接口是否可达」，与 statsig 缓存无关。
    本机日志实证：应用未登录（提示 Sign in to ChatGPT...），
    /settings/user 等账号接口 ERR_CONNECTION_TIMED_OUT，~/.codex/auth.json 不存在。
    结论：重置 Codex 会清掉登录态 -> 该菜单项消失；重新登录后即恢复。
#>
[CmdletBinding()]
param(
    [ValidateSet('menu', 'check', 'apply', 'restore', 'languages', 'clean', 'net', 'launch', 'report', 'switch', 'inject', 'online', 'diag')]
    [string]$Action = 'menu',
    [string]$Language = '',
    [switch]$Yes,
    [switch]$Pause
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- 基础环境
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
try { $OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

if ($PSScriptRoot) { $script:Root = $PSScriptRoot }
else { $script:Root = Split-Path -Parent $MyInvocation.MyCommand.Definition }

$script:AppName   = '睡醒的夜猫子 · Codex 一键汉化'
$script:Version   = 'v2.1.5'
$script:CfgPath   = Join-Path $env:USERPROFILE '.wakecat-i18n.json'
$script:CodexHome = Join-Path $env:USERPROFILE '.codex'
$script:ConfigToml = Join-Path $script:CodexHome 'config.toml'
$script:CuConfig  = Join-Path $script:CodexHome 'computer-use\config.json'
$script:BackupDir    = Join-Path $script:Root 'backups'
$script:BackupDirAlt = Join-Path $env:LOCALAPPDATA 'Codex-i18n\backups'
$script:State     = @{}
$script:Probe     = $null
$script:SwitchState = $null
$script:Verdict     = $null
$script:TcpProbe    = $null

# 条件二取证用常量：应用内置的 Statsig 客户端 key（客户端 key，非机密）与汉化开关的 Layer ID
$script:StatsigKey   = 'client-sYWqzCYMRkUg4DqqiZcR5DGTNl2iD7zNJY0HoeDLzxR'
$script:StatsigLayer = '72216192'
$script:StatsigUrl   = 'https://ab.chatgpt.com/v1/initialize?k=client-sYWqzCYMRkUg4DqqiZcR5DGTNl2iD7zNJY0HoeDLzxR'

# 离线注入用常量（v2.1.0，全部经 app.asar 逐字确认 + 本机 E2E 实测）：
#  · 缓存键 = DJB2("uid:|cids:source_surface_stable_id-<sid>,stableID-<sid>|k:<sdkKey>")，DJB2 初值为 0
#  · stable_id 的存储键后缀 = DJB2("k:"+sdkKey) = 685440364，跨机器常量
$script:OfflineStableId = '0e19a6c2-4a5b-4d8e-b3f7-2c9d8e1f0a36'   # 仅作参考，实际不再使用（凭空造 sid 会导致键对不上）
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

# PowerShell 5.1 / .NET 4.x 默认可能只协商 TLS 1.0，直连 Cloudflare 会握手失败
try {
    [System.Net.ServicePointManager]::SecurityProtocol =
        [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
} catch { }

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

# ------------------------------------------------- 语言开关 (Statsig enable_i18n)
# 界面语言 = config.toml 的 localeOverride  AND  应用远程开关 enable_i18n。
# 后者由应用启动时向 https://ab.chatgpt.com/v1/initialize 拉取（服务端无条件 true），
# 结果缓存进应用自己的 Local Storage(LevelDB)。
# 这套函数负责：定位缓存（软信号）、读系统代理、实测开关能否取到、以及分步修复引导。

function Read-FileBytes([string]$path) {
    # 应用运行时 LevelDB 的部分文件（MANIFEST / .log）被独占打开，
    # ReadAllBytes 会直接抛异常；换成 FileShare.ReadWrite 打开就能读到。
    # 读不到时返回 $null。
    try { return [System.IO.File]::ReadAllBytes($path) } catch { }
    try {
        $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $len = $fs.Length
            if ($len -le 0) { return $null }
            $buf = New-Object byte[] ([int]$len)
            $read = 0
            while ($read -lt $buf.Length) {
                $n = $fs.Read($buf, $read, $buf.Length - $read)
                if ($n -le 0) { break }
                $read += $n
            }
            return $buf
        } finally { $fs.Close() }
    } catch { return $null }
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

function Clear-EfsAttribute([string]$Dir) {
    # 兜底：万一目标目录继承了加密属性，用系统自带 cipher 解掉，
    # 保证加速包能被别的电脑 / 别的账户读取。返回 $true 表示目录内已无加密文件。
    $enc = @(Get-ChildItem -LiteralPath $Dir -File -Force -ErrorAction SilentlyContinue |
             Where-Object { $_.Attributes -band [System.IO.FileAttributes]::Encrypted })
    if ($enc.Count -eq 0) { return $true }
    $ci = Join-Path $env:SystemRoot 'System32\cipher.exe'
    if (Test-Path -LiteralPath $ci) {
        & $ci /d /s:$Dir | Out-Null
        $enc = @(Get-ChildItem -LiteralPath $Dir -File -Force -ErrorAction SilentlyContinue |
                 Where-Object { $_.Attributes -band [System.IO.FileAttributes]::Encrypted })
    }
    return ($enc.Count -eq 0)
}

function Copy-FileTreePlain {
    # 导出专用：以「读出明文 -> 写新文件」的方式复制。
    # 源文件带 EFS 加密属性时，robocopy 会把加密属性一并带过去，
    # 这样的包换台电脑 / 换个账户就打不开，所以必须走读写复制得到明文。
    # 返回成功复制的文件数，-1 表示失败。
    param([string]$Source, [string]$Dest, [string]$Exclude = 'LOCK')
    if (-not (Test-Path -LiteralPath $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
    $n = 0
    foreach ($f in @(Get-ChildItem -LiteralPath $Source -File -Force -ErrorAction SilentlyContinue)) {
        if ($Exclude -and $f.Name -eq $Exclude) { continue }
        try {
            $bytes = Read-FileBytes $f.FullName
            if ($null -eq $bytes) { return -1 }
            [System.IO.File]::WriteAllBytes((Join-Path $Dest $f.Name), $bytes)
            $n++
        } catch { return -1 }
    }
    $n
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

function Test-IsElevated {
    try {
        $wp = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
        return $wp.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Invoke-SelfElevate {
    # 以管理员权限重新拉起本工具。
    # 用途：应用的数据文件若由「管理员权限的进程」创建过，会带高完整性标签(High IL)，
    #       普通权限下只读不可写（DACL 里看不出任何异常，报错就是"访问被拒绝"）。
    param([string]$Action = 'menu')
    $ps     = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $self   = $script:PSCommandPath
    if (-not $self -or -not (Test-Path -LiteralPath $self)) { $self = Join-Path $script:Root 'Codex一键汉化.ps1' }
    $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $self + '"'), '-Action', $Action, '-Pause')
    Write-C '  正在请求管理员权限…（会弹出 UAC 确认框，请选"是"）' 'Yellow'
    try { Start-Process -FilePath $ps -ArgumentList $psArgs -Verb RunAs -ErrorAction Stop }
    catch { Write-C "  [X] 提权失败或被取消：$($_.Exception.Message)" 'Red'; return }
    Write-C '  已在新窗口中以管理员身份继续；本窗口可以关闭了。' 'Green'
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

# ---------------------------------------------------------------- 条件二：远程开关
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

function Test-Tcp443 {
    # 快速 TCP 探测：判断某个域名在「直连」情况下通不通（不走代理）
    param([string]$HostName, [int]$TimeoutMs = 3000)
    $c = $null
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $iar = $c.BeginConnect($HostName, 443, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) { return '超时' }
        $c.EndConnect($iar)
        return '可达'
    } catch { return '失败' }
    finally { if ($c) { try { $c.Close() } catch { } } }
}

function Invoke-StatsigProbe {
    # 直接向应用默认的 initialize 端点发一次同样的请求，读回 enable_i18n 的真实取值。
    # 该端点的这一层在服务端是 rule_id=default（无条件下发），所以用一个随机探针账号
    # 取到的结果，与本机应用取到的结果一致。
    param([string]$ProxyUri = '', [int]$TimeoutMs = 15000, [int]$Retries = 3)
    # 注意：实测这条链路会偶发 "connection was closed on send"（TLS/代理在首包握手上抽风）。
    # 单次失败不代表拿不到开关 —— 必须重试，否则会把「代理其实是好的」误报成「代理没配好」。
    $body = '{"user":{"userID":"wakecat-probe"},"statsigMetadata":{"sdkName":"js-client","sdkVersion":"3.33.4"},"sinceTime":0,"hash":"djb2"}'
    if ($Retries -lt 1) { $Retries = 1 }
    $lastErr = ''
    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        if ($attempt -gt 1) { Start-Sleep -Milliseconds 700 }
        try {
            $req = [System.Net.HttpWebRequest]::Create($script:StatsigUrl)
            $req.Method = 'POST'
            $req.ContentType = 'application/json'
            $req.UserAgent = 'Mozilla/5.0'
            $req.Timeout = $TimeoutMs
            $req.ReadWriteTimeout = $TimeoutMs
            if ($ProxyUri) { $req.Proxy = New-Object System.Net.WebProxy($ProxyUri) }
            else { $req.Proxy = New-Object System.Net.WebProxy }   # 空地址 = 强制直连，忽略系统代理
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
            $req.ContentLength = $bytes.Length
            $rs = $req.GetRequestStream()
            $rs.Write($bytes, 0, $bytes.Length)
            $rs.Close()
            $resp = $req.GetResponse()
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
            $text = $sr.ReadToEnd()
            $sr.Close(); $resp.Close()

            $enable = $null
            $i = $text.IndexOf('"enable_i18n"')
            if ($i -ge 0) {
                $len = [Math]::Min(200, $text.Length - $i)
                $m = [regex]::Match($text.Substring($i, $len), '"enable_i18n"\s*:\s*(true|false)')
                if ($m.Success) { $enable = ($m.Groups[1].Value -eq 'true') }
            }
            return [pscustomobject]@{ Ok = $true; Enable = $enable; Bytes = $text.Length; Error = ''; Attempts = $attempt }
        } catch {
            $lastErr = $_.Exception.Message
            # 内侧异常里更有用的那条（"send"/"receive" 之类）常常是 InnerException
            if ($_.Exception.InnerException) { $lastErr = $_.Exception.InnerException.Message }
        }
    }
    [pscustomobject]@{ Ok = $false; Enable = $null; Bytes = 0; Error = $lastErr; Attempts = $Retries }
}

function Get-SwitchVerdict {
    # 权威判定：应用到底能不能拿到 enable_i18n。
    # 应用走的是系统代理（跟浏览器一样）；所以我们优先按系统代理去测。
    param([switch]$Refresh, [int]$TimeoutMs = 15000)
    if (-not $Refresh -and $script:Verdict) { return $script:Verdict }

    $cfg = Get-Cfg
    $sp = Get-SystemProxy
    $manual = ''
    if ($cfg.proxy) { $manual = "$($cfg.proxy)".Trim() }

    $r = [ordered]@{
        SysProxy = $sp; Manual = $manual; Primary = ''; PrimaryOk = $false; Enable = $null
        Error = ''; Alt = ''; AltOk = $false; AltEnable = $null; Tested = $false
        Attempts = 0
    }

    if ($sp.Enabled -and $sp.Uri) { $r.Primary = "系统代理 $($sp.Uri)"; $px = $sp.Uri }
    else { $r.Primary = '直连（未开启系统代理）'; $px = '' }

    $res = Invoke-StatsigProbe -ProxyUri $px -TimeoutMs $TimeoutMs
    $r.Tested = $true
    $r.Attempts = $res.Attempts
    if ($res.Ok) { $r.PrimaryOk = $true; $r.Enable = $res.Enable } else { $r.Error = $res.Error }

    # 对照一组：用来区分「代理没配好」还是「域名被墙」
    if ($px) { $am = '直连'; $ax = '' }
    elseif ($manual) { $am = "本工具代理 $manual"; $ax = $manual }
    else { $am = ''; $ax = '' }
    if ($am) {
        $ra = Invoke-StatsigProbe -ProxyUri $ax -TimeoutMs $TimeoutMs
        $r.Alt = $am
        $r.AltOk = $ra.Ok
        $r.AltEnable = $ra.Enable
    }

    $script:Verdict = [pscustomobject]$r
    $script:Verdict
}

function Show-SwitchVerdict {
    # 把判定结果翻译成一句人话 + 下一步动作
    param($Vd, [switch]$Brief)
    if (-not $Vd -or -not $Vd.Tested) {
        Write-C '        尚未检测。进菜单 [8] 做一次在线自检（或直接看应用是否已是中文）。' 'DarkGray'
        return
    }
    if ($Vd.PrimaryOk -and $Vd.Enable -eq $true) {
        Write-C "        [OK] 通过 $($Vd.Primary) 取到开关：enable_i18n = true" 'Green'
        if ($Vd.Attempts -gt 1) {
            Write-C "             （链路有点抖，自动重试到第 $($Vd.Attempts) 次才成功 —— 结果仍然有效）" 'DarkGray'
        }
        Write-C '             条件二满足。若界面还是英文，完全退出应用（托盘图标右键 -> 退出）' 'Gray'
        Write-C '             再重新打开即可；已经中文的机器不用再管。' 'Gray'
        return
    }
    if ($Vd.PrimaryOk -and $Vd.Enable -ne $true) {
        Write-C "        [!] 请求成功，但 enable_i18n = $($Vd.Enable)（预期 true）" 'Red'
        Write-C '             这通常说明请求打到的是被劫持/缓存污染的响应，请检查代理是否做了' 'Gray'
        Write-C '             中间人替换，或换个代理节点再试。' 'Gray'
        return
    }
    Write-C "        [X] 拿不到开关：$($Vd.Primary) 请求失败（已自动重试 $($Vd.Attempts) 次）" 'Red'
    if ($Vd.Error) { Write-C "            原因：$($Vd.Error)" 'DarkGray' }
    if ($Vd.Alt) {
        if ($Vd.AltOk) {
            Write-C "            但换成「$($Vd.Alt)」是可以拿到配置的 —— 说明域名没问题，" 'Yellow'
            Write-C '            是应用要走的这条路（系统代理）没生效。' 'Yellow'
        } else {
            Write-C "            （对照：$($Vd.Alt) 同样失败）" 'DarkGray'
        }
    } elseif (-not $Vd.SysProxy.Enabled) {
        Write-C '            对照：当前直连也失败，且系统代理没开 —— 这就是根因。' 'Yellow'
    }
    if (-not $Brief) {
        Write-Host ''
        Write-C '        ---- 修复步骤（照做即可） ----' 'Cyan'
        Write-C '        1) 打开你的代理软件，开启「系统代理」或「TUN 模式」，' 'White'
        Write-C '           不要只开浏览器插件/只给某个 App 走代理。' 'White'
        Write-C '        2) 确认代理规则里 ab.chatgpt.com 是走代理的。' 'White'
        Write-C '           很多订阅只写了 chatgpt.com / openai.com，漏掉这个域名，' 'Gray'
        Write-C '           结果就是「应用能登录、就是拿不到汉化开关」。' 'Gray'
        Write-C '           最省事的做法：切到全局（Global）模式跑一次。' 'Gray'
        Write-C '        3) 完全退出 Codex（托盘图标右键 -> 退出，关窗口不算），再重新打开。' 'White'
        Write-C '        4) 等 10~15 秒，界面会自己切成中文（只需成功一次，之后离线也有效）。' 'White'
        Write-C '        5) 回到本工具点 [R] 刷新面板，或再做一次 [8] 复测。' 'White'
    }
}

function Get-SwitchState {
    param([switch]$Refresh)
    if (-not $Refresh -and $script:SwitchState) { return $script:SwitchState }

    $r = [ordered]@{
        ProfileRoot = ''; LevelDb = ''; Exists = $false; Size = [int64]0; Stamp = $null
        Cache = $false; CacheFlag = ''; StableId = $false; Session = $false; Error = ''
        SysProxy = (Get-SystemProxy)
    }
    $pr = Find-ProfileRoot
    if ($pr) { $r.ProfileRoot = $pr }
    $lp = Get-StorageLevelDb $pr
    if (-not $lp) {
        $r.Error = '未找到应用本地存储目录（应用从未启动过时属正常）'
        $script:SwitchState = [pscustomobject]$r
        return $script:SwitchState
    }
    $r.LevelDb = $lp
    $r.Exists = $true
    $files = @(Get-ChildItem -LiteralPath $lp -File -Force -ErrorAction SilentlyContinue)
    $sum = ($files | Measure-Object -Property Length -Sum).Sum
    if ($null -ne $sum) { $r.Size = [int64]$sum }
    $newest = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($newest) { $r.Stamp = $newest.LastWriteTime }

    # 注意两件事：
    #   1) localStorage 的值在 LevelDB 里以 UTF-16LE 存放（v1.2.0 的 ASCII 扫描因此全部漏报）；
    #   2) 历史数据会被 snappy 压缩进 .ldb，纯文本扫不到。
    # 所以这里只扫未压缩的 .log（最近写入）做「软信号」，权威判定看 Get-SwitchVerdict 的联网实测。
    $keys = @('statsig.cached.evaluations', 'statsig.stable_id', 'statsig.session_id')
    foreach ($f in $files) {
        if ($f.Length -le 0 -or $f.Length -gt 64MB) { continue }
        $b = Read-FileBytes $f.FullName
        if ($null -eq $b) { continue }
        $u = [System.Text.Encoding]::Unicode.GetString($b)
        $a = [System.Text.Encoding]::ASCII.GetString($b)
        foreach ($k in $keys) {
            if ($u.Contains($k) -or $a.Contains($k)) {
                if ($k -eq 'statsig.cached.evaluations') { $r.Cache = $true }
                elseif ($k -eq 'statsig.stable_id') { $r.StableId = $true }
                else { $r.Session = $true }
            }
        }
        if ($u.Contains('"enable_i18n":true') -or $a.Contains('"enable_i18n":true') -or $u.Contains('"enable_i18n": true')) { $r.CacheFlag = 'true' }
        elseif ($u.Contains('"enable_i18n":false') -or $a.Contains('"enable_i18n":false') -or $u.Contains('"enable_i18n": false')) { $r.CacheFlag = 'false' }
    }
    $script:SwitchState = [pscustomobject]$r
    $script:SwitchState
}

function Test-AppRunning {
    @(Get-Process -Name 'ChatGPT', 'Codex', 'codex' -ErrorAction SilentlyContinue).Count -gt 0
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
    # 由「运行中的进程」定位到应用时没有包信息，按安装路径反查一次包；
    # 否则会退到 exe 的 ProductVersion —— 那是 Electron/Chromium 的版本号（如 152.x），容易误导。
    if (-not $r.Version) {
        try {
            $hit = @(Get-AppxPackage -ErrorAction SilentlyContinue |
                     Where-Object { $_.InstallLocation -and $app.Path.StartsWith($_.InstallLocation, [System.StringComparison]::OrdinalIgnoreCase) } |
                     Select-Object -First 1)
            if ($hit.Count -gt 0) {
                $r.Version = "$($hit[0].Version)"
                $r.FamilyName = $hit[0].PackageFamilyName
                $r.Kind = 'MSIX'
            }
        } catch { }
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
        $rows.Add(@('应用', '未找到 (菜单 [9] 可手动指定路径)', 'Red'))
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

    # 系统代理 —— 应用的 Electron 网络栈走的就是它，条件二成败与否基本取决于这里
    $sp = Get-SystemProxy
    if ($sp.Enabled -and $sp.Uri) {
        $rows.Add(@('系统代理', "已开启 $($sp.Uri)   (应用走的就是它)", 'Green'))
    } elseif ($sp.AutoConfig) {
        $rows.Add(@('系统代理', "PAC 自动配置 $($sp.AutoConfig)", 'Gray'))
    } elseif ($sp.Note) {
        $rows.Add(@('系统代理', $sp.Note, 'Yellow'))
    } else {
        $rows.Add(@('系统代理', '未开启  <- 应用拉汉化开关要靠它', 'Yellow'))
    }

    if ($script:Verdict -and $script:Verdict.Tested) {
        $vd = $script:Verdict
        if ($vd.PrimaryOk -and $vd.Enable -eq $true) {
            $rows.Add(@('语言开关', "enable_i18n = true  ($($vd.Primary)) · 中文可用", 'Green'))
        } elseif ($vd.PrimaryOk) {
            $rows.Add(@('语言开关', "enable_i18n = $($vd.Enable)  ($($vd.Primary))  -> [8]", 'Red'))
        } else {
            $rows.Add(@('语言开关', "拉取失败（$($vd.Primary)）  -> [7] 离线注入 或 [8] 在线修复", 'Red'))
        }
    } else {
        # 面板一律不做联网探测：以前这里每次重绘都白等 2.5 秒 TCP 超时，非常拖沓。
        # 想看 ab.chatgpt.com 通不通，进 [8] 在线诊断 / [9] 网络检测；纯离线走 [7]。
        $col = if ($sp.Enabled -and $sp.Uri) { 'Gray' } else { 'Yellow' }
        $note = if ($sp.Enabled -and $sp.Uri) { '（已开代理，规则需覆盖该域名）' } else { '直连被墙；无代理请用 [7] 离线注入' }
        $rows.Add(@('汉化开关', "未做联网检测（面板纯本地）  $note", $col))
    }

    if ($cfg.proxy) { $rows.Add(@('本工具代理', $cfg.proxy, 'DarkGray')) }

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
        'zh-tw' = 'zh-TW'; 'zh-hk' = 'zh-HK'; 'ja' = 'ja-JP'; 'ko' = 'ko-KR'
    }
    # 英文是应用的内建回退语言，包内并没有 en-US.json。
    # 写 en-US 也能回退成英文，但正确做法是直接摘掉 localeOverride（走 [4] 还原逻辑）。
    if ($want -match '^(en|en-us|en-gb|english|英文|英语)$') { return '' }
    if ($alias.ContainsKey($want.ToLower())) { return $alias[$want.ToLower()] }
    $want
}

function Invoke-Apply([string]$locale) {
    $p = Get-AppProbe -Refresh
    if (-not $p.Found) { Write-C '  [X] 未找到 ChatGPT / Codex 桌面版，请用菜单 [9] 手动指定安装路径。' 'Red'; return }
    # 目标语言解析成空 = 用户要的是英文，交给还原逻辑
    if (-not $locale -or $locale -eq 'en-US') { Invoke-Restore; return }
    if ($p.Locales.Count -gt 0 -and ($p.Locales -notcontains $locale)) {
        Write-C "  [X] 该应用不提供语言 `"$locale`"。" 'Red'
        Write-C "      可用语言：$($p.Locales -join ', ')" 'Gray'
        return
    }

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
    Write-C '  条件一（localeOverride）已完成。' 'Green'
    Write-C '  界面语言由应用官方开关控制，应用商店升级后依然有效。' 'Green'

    Write-Host ''
    Write-C '  [校验] 条件二：远程开关 enable_i18n' 'Cyan'
    Write-C '        语言包本身 100% 内置；界面到底切不切中文，取决于应用能不能' 'Gray'
    Write-C '        从 https://ab.chatgpt.com/v1/initialize 把开关拿下来一次。' 'Gray'
    Write-Host ''
    $vd = Get-SwitchVerdict -Refresh -TimeoutMs 12000
    Show-SwitchVerdict $vd -Brief
    $sw = Get-SwitchState -Refresh
    Write-Host ''
    if ($sw.Exists) {
        Write-C ("        应用本地存储：$($sw.LevelDb)") 'DarkGray'
    } else {
        Write-C ("        $($sw.Error)") 'DarkGray'
    }
    Write-Host ''
    Write-C '  若条件二也通过了、界面仍是英文：完全退出应用（托盘图标右键 -> 退出）后重启即可。' 'Gray'
    Write-C '  若条件二没通过：[7] = 离线注入（纯本地，秒出，无需代理）；[8] = 在线自检修复。' 'Yellow'
    Write-C '  （v1.2.0 的「汉化加速包」已删除：搬来的缓存键绑的是原机器的 stableID，' 'DarkGray'
    Write-C '    换台机器就对不上号 —— 所以改成「读本机 stableID 现场算键再注入」。）' 'DarkGray'
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
    Write-C '  界面语言开关（条件二）：' 'Cyan'
    $sp = Get-SystemProxy
    if ($sp.Enabled -and $sp.Uri) {
        Write-C ("    系统代理        : 已开启 $($sp.Uri)") 'Green'
    } elseif ($sp.AutoConfig) {
        Write-C ("    系统代理        : PAC $($sp.AutoConfig)") 'Gray'
    } else {
        Write-C '    系统代理        : 未开启  <- 应用要靠它才能拿到开关' 'Yellow'
    }
    $tk = Test-Tcp443 -HostName 'ab.chatgpt.com' -TimeoutMs 4000
    Write-C ("    关键域名直连    : ab.chatgpt.com [$tk]   (该域名国内直连必超时，属正常)") 'Gray'
    Write-Host ''
    $vd = Get-SwitchVerdict -Refresh -TimeoutMs 12000
    Write-C ("    实测路径        : " + $vd.Primary) 'Gray'
    Show-SwitchVerdict $vd
    $sw = Get-SwitchState -Refresh
    if ($sw.Exists) {
        Write-C ("    本地存储        : " + $sw.LevelDb) 'DarkGray'
        $stampTxt = if ($sw.Stamp) { $sw.Stamp.ToString('yyyy-MM-dd HH:mm:ss') } else { '?' }
        Write-C ("    体积 / 更新时间 : " + (Fmt-Size $sw.Size) + "  ·  " + $stampTxt) 'Gray'
        $flagTxt = if ($sw.CacheFlag) { "读到取值 $($sw.CacheFlag)" } elseif ($sw.Cache) { '有缓存条目（取值未读到）' } else { '未在未压缩日志里读到' }
        Write-C ("    缓存里的开关    : " + $flagTxt + "   (软信号，权威判定看上面的实测)") 'DarkGray'
    } else {
        Write-C ("    " + $(if ($sw.Error) { $sw.Error } else { '未找到' })) 'Gray'
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
            Write-C "    [OK] 条件一：官方中文资源完整，localeOverride = `"$toml`"。" 'Green'
        } else {
            Write-C '    [!] 条件一：中文资源完整，但 localeOverride 未指向中文，请执行 [1] 一键汉化。' 'Yellow'
        }
    } elseif ($p.Found) {
        Write-C '    [!] 条件一：未检测到内置中文资源，该版本可能不提供简体中文。' 'Yellow'
    }
    if ($vd.Tested -and $vd.PrimaryOk -and $vd.Enable -eq $true) {
        Write-C '    [OK] 条件二：实测 enable_i18n = true，应用下次启动就能拿到中文界面。' 'Green'
    } else {
        Write-C '    [!] 条件二：实测拿不到 enable_i18n。语言包是内置的，但这个开关必须由应用' 'Yellow'
        Write-C '        联网向 ab.chatgpt.com 拉一次 —— 该域名在国内被墙，开系统代理/TUN 并' 'Yellow'
        Write-C '        确保代理规则覆盖它即可。菜单 [8] 有分步操作（[9] 可先做连通性检测）。' 'Yellow'
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

# ---------------------------------------------------------------- 远程开关自检与修复
# ---------------------------------------------------------------- 离线注入（v2.1.0）
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

function Invoke-SwitchFix {
    param([switch]$NoPrompt)
    while ($true) {
        Write-Host ''
        Write-C '  === [8] 在线诊断与修复（需要网络 / 代理）=====================' 'Cyan'
        Write-C '  纯离线机器请直接用菜单 [7]：不联网、不做探测、秒级完成。' 'Yellow'
        Write-C '  界面语言由两个条件共同决定：' 'Gray'
        Write-C '    条件一 localeOverride        —— 本工具负责，纯本地即可完成（菜单 [1]）' 'Gray'
        Write-C '    条件二 远程开关 enable_i18n  —— 应用启动时向 ab.chatgpt.com 拉取' 'Gray'
        Write-Host ''
        Write-C '  关键事实：这个开关在服务端是【无条件下发】的（rule_id = default），' 'White'
        Write-C '  跟账号、设备、抽签百分比都无关 —— 也就是说，应用只要能成功访问' 'White'
        Write-C '  ab.chatgpt.com 一次，界面就会变中文，之后离线也长期有效。' 'White'
        Write-C '  而该域名在国内被 DNS 污染 + TCP 超时，于是出现「应用能登录、界面却永远英文」。' 'Yellow'
        Write-Host ''
        Write-C '  ---- 实测 ----' 'Cyan'

        $sp = Get-SystemProxy
        if ($sp.Enabled -and $sp.Uri) { Write-C ("    · 系统代理                : 已开启 $($sp.Uri)") 'Green' }
        elseif ($sp.AutoConfig) { Write-C ("    · 系统代理                : PAC $($sp.AutoConfig)") 'Gray' }
        else { Write-C '    · 系统代理                : 未开启' 'Yellow' }
        $d1 = Test-Tcp443 -HostName 'ab.chatgpt.com' -TimeoutMs 5000
        $d2 = Test-Tcp443 -HostName 'api.oaistatsig.com' -TimeoutMs 5000
        Write-C ("    · ab.chatgpt.com   直连   : $d1   <- 汉化开关就从这个域名下发") 'Gray'
        Write-C ("    · api.oaistatsig.com 直连 : $d2   <- 事件上报用，国内通常直连通") 'DarkGray'

        $vd = Get-SwitchVerdict -Refresh -TimeoutMs 15000
        Write-C ("    · 实测路径                : $($vd.Primary)") 'Gray'
        Show-SwitchVerdict $vd

        Write-Host ''
        Write-C '  ---- 说明 ----' 'DarkGray'
        Write-C '    · 只需成功一次：开关结果会缓存进应用本地，之后换网络 / 断网都还是中文。' 'DarkGray'
        Write-C '    · 「菜单栏是中文」不代表汉化成功：原生菜单跟随系统语言，' 'DarkGray'
        Write-C '      界面文字才看 enable_i18n 这个开关 —— 这正是「菜单中文、界面英文」的由来。' 'DarkGray'
        Write-C '    · 缓存键 statsig.cached.evaluations.<hash> 的输入只有本机 stableID' 'DarkGray'
        Write-C '      （v1.2.0「加速包」失败是因为整目录照搬了别台机器的键，不是机制不允许）' 'DarkGray'
        Write-C '      —— 所以没代理 / 离线的新机器可以用选项 2) 直接离线注入。' 'DarkGray'

        Write-Host ''
        Write-C '    1) 重新检测' 'White'
        Write-C '    2) 离线开关注入（同菜单 [7]；不联网时直接用它）' 'White'
        Write-C '    3) 启动 / 重启应用（让它去拉开关）' 'White'
        Write-C '    4) 保存诊断报告到文件' 'White'
        Write-C '    0) 返回' 'White'
        Write-Host ''
        if ($NoPrompt -or -not (Test-Interactive)) { return }
        $c = "$(Read-Host '  选择')".Trim()
        if ($c -eq '1') { $script:Verdict = $null; $script:TcpProbe = $null; continue }
        if ($c -eq '2') { Invoke-OfflineInject; continue }
        if ($c -eq '3') {
            Invoke-Launch
            Write-C '  等 10~15 秒看界面是否变成中文；只需成功一次。' 'White'
            Write-Host ''
            Write-C '  按回车继续…' 'DarkGray'
            [void](Read-Host)
            continue
        }
        if ($c -eq '4') { Save-DiagReport; continue }
        if ($c -eq '0') { return }
        Write-C '  无效选择。' 'Red'
    }
}

function Save-DiagReport {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $path = Join-Path $script:Root ("诊断报告-$stamp.txt")
    $L = New-Object System.Collections.Generic.List[string]
    $L.Add('睡醒的夜猫子 · Codex 一键汉化  诊断报告')
    $L.Add("工具版本   : $($script:Version)")
    $L.Add("生成时间   : $((Get-Date).ToString('s'))")
    $L.Add("计算机/用户: $env:COMPUTERNAME / $env:USERNAME")
    $L.Add("操作系统   : $([System.Environment]::OSVersion.VersionString)")
    $L.Add("PowerShell : $($PSVersionTable.PSVersion)")
    $L.Add('')
    $p = Get-AppProbe
    $L.Add("应用已找到 : $($p.Found)")
    if ($p.Found) {
        $L.Add("应用版本   : $($p.Version)")
        $L.Add("安装路径   : $($p.AppDir)")
    }
    $L.Add("配置目录   : $($script:CodexHome)")
    $L.Add("localeOverride : $(Get-TomlLocale $script:ConfigToml)")
    $L.Add('')
    $sp = Get-SystemProxy
    $L.Add("系统代理开关 : $($sp.Enabled)")
    $L.Add("系统代理地址 : $($sp.Server)")
    $L.Add("系统代理 PAC : $($sp.AutoConfig)")
    if ($sp.Note) { $L.Add("系统代理备注 : $($sp.Note)") }
    $L.Add('')
    foreach ($h in @('ab.chatgpt.com', 'api.oaistatsig.com', 'statsigcdn.openai.com', 'chatgpt.com')) {
        $L.Add("直连 TCP443 $h : $(Test-Tcp443 -HostName $h -TimeoutMs 5000)")
    }
    $L.Add('')
    $vd = Get-SwitchVerdict -Refresh -TimeoutMs 15000
    $L.Add("实测路径       : $($vd.Primary)")
    $L.Add("实测成功       : $($vd.PrimaryOk)")
    $L.Add("enable_i18n    : $($vd.Enable)")
    $L.Add("尝试次数       : $($vd.Attempts)")
    $L.Add("实测错误       : $($vd.Error)")
    if ($vd.Alt) { $L.Add("对照 $($vd.Alt) : Ok=$($vd.AltOk) enable_i18n=$($vd.AltEnable)") }
    $sw = Get-SwitchState -Refresh
    $L.Add('')
    $L.Add("本地存储目录   : $($sw.LevelDb)")
    $L.Add("本地存储存在   : $($sw.Exists)")
    $L.Add("本地存储体积   : $(Fmt-Size $sw.Size)")
    $L.Add("缓存软信号     : Cache=$($sw.Cache) Flag=$($sw.CacheFlag)")
    try {
        [System.IO.File]::WriteAllLines($path, $L.ToArray(), (New-Object System.Text.UTF8Encoding($true)))
        Write-Host ''
        Write-C "  [OK] 诊断报告已保存：" 'Green'
        Write-C "       $path" 'White'
        Write-C '       把这台机器的报告发回来即可定位。（不含任何账号 / 密钥信息）' 'Gray'
    } catch {
        Write-C "  [X] 保存失败：$($_.Exception.Message)" 'Red'
    }
    if (Test-Interactive) {
        Write-Host ''
        Write-C '  按回车继续…' 'DarkGray'
        [void](Read-Host)
    }
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
    Write-C '  === 网络 / 代理检测 ==========================================' 'Cyan'
    Write-C '  目的：确认应用能不能拿到汉化开关（enable_i18n）。' 'White'
    Write-Host ''

    $sp = Get-SystemProxy
    if ($sp.Enabled -and $sp.Uri) {
        Write-C ("  系统代理：已开启 $($sp.Uri)   （应用的 Electron 网络栈走的就是它）") 'Green'
    } elseif ($sp.AutoConfig) {
        Write-C ("  系统代理：PAC $($sp.AutoConfig)") 'Gray'
    } else {
        Write-C '  系统代理：未开启 —— 应用会直连，而关键域名在国内被墙。' 'Yellow'
    }
    if ($sp.Note) { Write-C ("            $($sp.Note)") 'DarkGray' }
    Write-Host ''

    $targets = @(
        @{ N = 'ab.chatgpt.com';        U = 'https://ab.chatgpt.com';        D = '<== 汉化开关：就从这个域名下发' },
        @{ N = 'api.oaistatsig.com';    U = 'https://api.oaistatsig.com';    D = '事件上报（国内通常可直连）' },
        @{ N = 'statsigcdn.openai.com'; U = 'https://statsigcdn.openai.com'; D = '配置 CDN 备用端点' },
        @{ N = 'chatgpt.com';           U = 'https://chatgpt.com';           D = '登录 / 对话主站' },
        @{ N = 'api.openai.com';        U = 'https://api.openai.com';        D = 'API' }
    )
    $proxyUri = if ($sp.Enabled -and $sp.Uri) { $sp.Uri } else { $cfg.proxy }

    Write-C ('    ' + (PadR '域名' 24) + (PadR '直连' 10) + (PadR '代理' 10) + '说明') 'White'
    foreach ($t in $targets) {
        $direct = Test-Tcp443 -HostName $t.N -TimeoutMs 5000
        $via = '无代理'
        if ($proxyUri) {
            $via = '不可达'
            try {
                $req = @{ Uri = $t.U; Method = 'Head'; TimeoutSec = 10; UseBasicParsing = $true
                          Proxy = $proxyUri; UserAgent = 'Mozilla/5.0' }
                Invoke-WebRequest @req | Out-Null
                $via = '可达'
            } catch {
                $m = "$($_.Exception.Message)"
                if ($m -match 'timed out|超时') { $via = '超时' } else { $via = '有响应' }
            }
        }
        $c1 = if ($direct -eq '可达') { 'Green' } else { 'Yellow' }
        $c2 = if ($via -eq '可达' -or $via -eq '有响应') { 'Green' } elseif ($via -eq '无代理') { 'DarkGray' } else { 'Red' }
        Write-Host ('    ' + (PadR $t.N 24)) -NoNewline
        Write-CN (PadR $direct 10) $c1
        Write-CN (PadR $via 10) $c2
        Write-C $t.D 'DarkGray'
    }

    Write-Host ''
    $vd = Get-SwitchVerdict -Refresh -TimeoutMs 15000
    $verdictTxt = if ($vd.PrimaryOk) { '请求成功' } else { '请求失败' }
    Write-C ("  开关实测（$($vd.Primary)）：$verdictTxt") 'White'
    Show-SwitchVerdict $vd
    Write-Host ''
    Write-C '  提示：' 'DarkGray'
    Write-C '    · 中文语言包 100% 内置于应用（原生菜单与前端 chunk 各 64 种语言，一一对应），' 'Gray'
    Write-C '      不需要下载；简体中文为 196 键 + 1.3 MB 前端资源。' 'Gray'
    Write-C '    · ab.chatgpt.com 在国内直连必然超时，所以「直连」列是超时属正常现象。' 'Gray'
    Write-C '    · 只要「代理」列那一行有响应，重启应用一次就能拿到中文；开关随即落盘，长期有效。' 'Gray'
    Write-C '    · chatgpt.com / api.openai.com 不通只影响登录与对话，与界面中文无关。' 'DarkGray'
    Write-C '    · 这个域名是很多代理订阅的漏网之鱼：规则里往往只写了 chatgpt.com / openai.com，' 'Yellow'
    Write-C '      记得补上 ab.chatgpt.com，或者临时切到全局（Global）模式跑一次。' 'Yellow'
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
        $spc = Get-SystemProxy
        $spTxt = if ($spc.Enabled -and $spc.Uri) { "已开启 $($spc.Uri)   (自动识别，应用也走它)" } else { '未开启（请在代理软件里开系统代理 / TUN）' }
        Write-C ("    系统代理       : $spTxt") 'Gray'
        Write-C ("    2) 备用代理     : " + $(if ($cfg.proxy) { $cfg.proxy } else { '(未设置；留空即自动使用系统代理)' })) 'White'
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
                $v = Read-Host '  输入备用代理，如 http://127.0.0.1:7890，留空=自动使用系统代理'
                $cfg.proxy = "$v".Trim()
                Save-Cfg $cfg
                $script:Verdict = $null
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
        @('[7] 离线注入汉化开关（纯本地）', '[8] 在线诊断与修复（联网）'),
        @('[9] 网络 / 代理检测', '[0] 设置'),
        @('[R] 刷新面板', '[Q] 退出')
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
            '7' { Invoke-OfflineInject }
            '8' { Invoke-SwitchFix }
            '9' { Invoke-Net }
            '0' { Invoke-Settings }
            'r' { Get-AppProbe -Refresh | Out-Null; $script:SwitchState = $null; $script:Verdict = $null; $script:TcpProbe = $null; continue }
            'q' { return }
            '' { continue }
            default { Write-C '  无效选择，请输入 0-9 / R / Q。' 'Red' }
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
        'inject'    { Invoke-OfflineInject -NoPrompt }
        'online'    { Invoke-SwitchFix -NoPrompt }
        'switch'    { Invoke-SwitchFix -NoPrompt }
        'diag'      { Save-DiagReport }
    }
} catch {
    Write-Host ''
    Write-C ("  [异常] " + $_.Exception.Message) 'Red'
    Write-C ("  " + $_.InvocationInfo.PositionMessage) 'DarkGray'
}

# 提权重启时（-Pause）留一个停顿，否则新窗口执行完立刻消失、看不到输出
if ($Pause) {
    Write-Host ''
    Write-C '  按回车关闭此窗口…' 'DarkGray'
    [void](Read-Host)
}
