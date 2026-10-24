# iFreePanel 镜像更新与安全响应策略

> 定稿：2026-10-24（php2shell 事件后） · 适用：`ghcr.io/ifreepanel` 全部自建镜像
> 事实源：本仓库 workflows；本文与 workflow 不同步时以 workflow 为准

## 一、版本支持矩阵

| 版本 | 状态 | 说明 |
|---|---|---|
| PHP 8.2 / 8.4 / 8.5 | **受支持** | 自动重建跟进上游补丁 |
| PHP 8.1 / 7.4 / 5.6 | **legacy（下架）** | EOL 不可修复；GHCR 镜像保留，仅供离线救急/历史兼容，**禁止用于互联网生产环境** |
| python-fastapi 3.15 | 受支持 | 手动/tag 触发 |
| caddy / mariadb 12.3+11.8 / postgresql 18 / redis 8.8 | 受支持 | 官方镜像 crane copy 原样搬运 |

下架决策依据（php2shell，CVE-2026-109618/109619，CVSS 9.2 未认证 RCE）：≤8.1 官方停更；
7.4/8.0/8.1 仅官方最小源码 backport（需自编译），5.6 连 backport 都没有；我方 5.6/7.4
基础层来自已冻结的 linuxeye 仓库，管线内无修复路径——**下架是唯一负责任的选择**。

## 二、更新触发机制（四层防线）

| 层 | 触发 | 覆盖 | 响应时间 |
|---|---|---|---|
| 1. 上游监视器 `watch-upstream.yml` | 每 6 小时对比官方 `php:{v}-fpm-bookworm` digest，变化自动 dispatch build.yml（防重：build-php 在跑则跳过） | PHP 8.2/8.4/8.5 | **~6 小时** |
| 2. 周更 `build.yml` cron | 每周六 02:00 UTC 全量重建受支持版本 | PHP 受支持版本 + 兜底 | ≤7 天 |
| 3. 手动应急 | dispatch build.yml 传 versions（可点名 legacy 版本） | 全部 | 当天 |
| 4. 组件刷新 `mirror-components.yml` | 每周一 cron + 手动 | caddy/mariadb/pg/redis | ≤7 天 |

机制说明：PHP base 层 `FROM php:{v}-fpm-bookworm` 是浮动 tag，重建即吃上游补丁版；
`8.5-prod` 这类 tag 语义为「该大版本的最新补丁」。组件镜像走 crane copy 原样搬运，
digest 变化随周一刷新跟进。

## 三、漏洞响应 SOP

1. **发现**：php.net 安全公告 / CERT 各国通报 / GitHub Advisory（建议 watch php/php-src releases）
2. **确认**：受影响版本线对照官方修复版清单（示例：8.5.12 / 8.4.27 / 8.3.36 / 8.2.35）
3. **重建**：监视器自动触发；或手动 dispatch（手机 GitHub App → Actions → build-php → Run workflow，versions 填受影响版本，全程 20-30 秒）
4. **验收**：run success 后匿名拉 `docker run --rm ghcr.io/ifreepanel/php-fpm:{v}-prod php -v`，确认补丁号 ≥ 修复版
5. **存量站点**：面板 detect 读 `php -v` 补丁号对比修复清单，低于即提示「镜像过期，请重拉」（开发侧待办）

## 四、官方缓解措施（补丁未到位时的缓冲，转开发）

按 php.net 建议，在 prod 层 php.ini / FPM pool 配置落实：

- `session.upload_progress.enabled=0`（封堵 stale global state 的确认路径）
- `memory_limit` 策略：FPM pool 用 `php_admin_value` 固定为不可被应用覆盖的值，
  并以容器内存上限（compose mem_limit/cgroup）作为可用性边界
- `post_max_size` / `upload_max_filesize` 收紧（无上传需求的站点 8M）

## 五、legacy 镜像处置约定

- 不删除：已 Public、零维护成本；老站客户救急仍是解法（差异化资产）
- 不自动重建：5.6/7.4 走手动点名 + legacy 导入步骤（workflow 保留）
- 面板 UI / components.json 不出现这些版本选项
- 文档口径统一：「不可修复的安全风险，勿用于生产」
