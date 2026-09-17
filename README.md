<div align="center">

# 睡醒的夜猫子 · Codex 一键汉化

**给 OpenAI Codex 桌面版（Microsoft Store / MSIX）换简体中文界面的 Windows 工具**

不修改应用文件 · 支持完全离线 · 商店升级不失效 · 无依赖

![platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D4)
![powershell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE)
![deps](https://img.shields.io/badge/dependencies-none-brightgreen)
![version](https://img.shields.io/badge/version-v2.1.5-blue)
![license](https://img.shields.io/badge/license-MIT-green)

</div>

---

**两个版本：**

| | 完整版（本目录） | 便携版（`Codex离线汉化-便携版\`） |
|---|---|---|
| 定位 | 日常使用，功能全（联网自检、诊断、清理等） | 拷 U 盘随身带，只保留离线汉化主干 |
| 汉化方式 | `[1]` 联网汉化 / `[7]` 离线注入 | `[1]` 一键离线汉化 |
| 体积 | ~119 KB | ~55 KB（3 个文件） |

## 原理：界面变中文的「两条腿」，缺一不可

**① 官方语言设置**：在 `~\.codex\config.toml` 写 `localeOverride = "zh-CN"`（官方支持，纯本地）。

**② 远程开关 `enable_i18n`**：由 `https://ab.chatgpt.com/v1/initialize` 下发。该域名在国内不可达
（DNS 污染 + 443 超时），而语言包其实 **100% 内置在应用里** —— 卡的只是这个开关。

- 机器能访问 `ab.chatgpt.com` 时（系统代理/TUN 且规则**覆盖 ab 子域**，很多订阅只写
  `chatgpt.com` 就漏了它），应用自己就能拿到开关 → **联网汉化，重启一次永久生效**。
- 拿不到时，本工具**离线注入**：读取本机 stableID → 按应用自身的键公式现场计算缓存键 →
  以 LevelDB 原生格式（WriteBatch + crc32c）往应用的 Local Storage 写入一条
  `enable_i18n = true` 的开关缓存 → 应用启动时照常读取，界面即中文。

关键事实：该开关在服务端**无条件恒为 true**（与账号/设备无关）；缓存键只由本机 stableID 决定，
所以每台机器都能现场算出、就地注入 —— 不需要下载语言包，也不需要搬运任何文件。

> 原生菜单栏语言跟系统，界面语言才受开关控制 ——"菜单中文、界面英文"并不矛盾。

## 快速开始

**完整版**：双击 `Codex一键汉化.cmd`（备用 `codex-i18n.cmd`）

- 能联网（代理覆盖 `ab.chatgpt.com`）→ 选 `[1]` 联网汉化，重启应用即可
- 无法联网 → 选 `[7]` → `2` 离线开关注入（应用需先完全退出）

**便携版**：把 `Codex离线汉化-便携版\` 整个文件夹拷到 U 盘，在目标机器上：

1. 安装 Codex 并**启动一次**（生成用户数据），然后完全退出
2. 双击 `Codex离线汉化-便携版.cmd` → `[1]` 一键离线汉化 → `[2]` 启动应用 → 界面即中文

命令行（完整版）：`-Action menu|check|apply|restore|languages|clean|net|launch|report|switch|diag|inject`

## 常见问题

**Q：汉化能撑多久？什么时候要重跑？**
一次注入长期有效。只有「重置/清空应用数据」（或卸载重装）会清掉缓存 → 重跑一次即可（幂等）。商店升级不失效。

**Q：注入后为什么浏览器操控 / 电脑操控显示"已被你的组织停用"？**
离线注入是裁剪版响应（只含汉化开关），其余未知开关按"不可用"处理 —— 这是离线方案知情换来的代价。
想要功能齐全 + 中文，让应用真连上一次 `ab.chatgpt.com` 即可。

**Q：设置里能选中文，选了却没反应？**
应用内语言选择器与语言包加载侧读取的开关默认值不同，最终仍以 `enable_i18n` 为准 —— 用本工具写入即可。

**Q：杀毒软件报毒？**
写 LevelDB 缓存的行为可能被误报，加入信任区即可。本工具不改应用文件、无任何联网上传。

## 它改了什么

- ✅ 写 `~\.codex\config.toml` 一行 `localeOverride`
- ✅ 往应用的 Local Storage 写开关缓存（注入前自动备份，写后 CRC 自检，失败即中止）
- ❌ 不改应用安装目录的任何文件（所以商店升级不会"修复"掉汉化）

## 目录结构

```
├── Codex一键汉化.ps1            完整版主脚本
├── Codex一键汉化.cmd            完整版双击入口
├── codex-i18n.cmd               完整版备用入口（ASCII 文件名）
└── Codex离线汉化-便携版/        便携版（拷 U 盘即用）
    ├── Codex-Offline-CN.ps1
    ├── Codex离线汉化-便携版.cmd
    └── README-使用说明.txt
```

## 免责声明

本工具仅调用应用自身能力（官方语言设置 + 本地缓存写入），不修改、不逆向分发应用文件，
不与 OpenAI 交互上传任何数据。请从 Microsoft Store 获取正版应用。使用本工具产生的任何后果由使用者承担。

## 许可

[MIT](LICENSE) ｜ 睡醒的夜猫子（守夜）🕯️
