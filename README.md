# ifree-images

iFreePanel 的自建容器镜像仓库：**PHP-FPM 多版本运行时**（6 LTS）、**Python-FastAPI 运行时底座**与**基础组件镜像**，全部 linux/amd64 + linux/arm64 双架构。

## 产物一览

### PHP-FPM —— `ghcr.io/iFreePanel/php-fpm:{版本}-prod`

基础配方基于 `linuxeye/docker-php-fpm`（MIT），在其上做了参数化与容器内配置定制。

| 版本 | 状态 | base 层来源 |
|---|---|---|
| 8.2 / 8.4 / 8.5 | **受支持**（每周六自动重建跟进上游补丁） | 官方 `php:{v}-fpm-bookworm` 全链自主 |
| 8.1 | legacy（EOL，php2shell 起下架，不可自动修复） | 官方 bookworm，存档不再更新 |
| 5.6 / 7.4 | legacy（EOL + linuxeye 基础层冻结，**无法修复安全漏洞**） | linuxeye 私造基础镜像（stretch/buster） |

> 2026-10-24 php2shell（CVE-2026-109618/109619）起，支持矩阵收敛为 8.2/8.4/8.5。
> legacy 镜像保留在 GHCR 仅供离线救急/历史兼容，**不要用于互联网生产环境**。

三层语义（继承上游）：**base** = PHP 核心；**mods** = 预编译全部扩展（~70 个）；**prod** = composer + 运行时收尾。iFreePanel 面板与离线包只用 `-prod`。

### Python-FastAPI —— `ghcr.io/iFreePanel/python-fastapi:3.15`（及 `latest`）

Python 3.15 slim 底座，预烘焙最新版 FastAPI + uvicorn（含 standard 扩展，C 扩展轮子缺失时自动退回纯 Python 核心）。目标机零联网，应用镜像在此底座上叠加构建：

```dockerfile
FROM ghcr.io/ifreepanel/python-fastapi:3.15
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 基础组件 —— `ghcr.io/iFreePanel/{caddy|mariadb|postgresql|redis}:{tag}`

官方镜像经 `crane copy` 原样搬运（保留完整多架构清单，零改动零重建），组件矩阵与 iFreePanel 首发组件收敛决策对齐：

| 镜像 | 源 tag | 角色 |
|---|---|---|
| `caddy:latest` | caddy:latest | web/edge 唯一轨（自动 SSL） |
| `mariadb:12.3` | mariadb:12.3 | 数据库主力（最新 LTS，社区维护至 2029） |
| `mariadb:11.8` | mariadb:11.8 | 次新 LTS 备胎（pull-images.sh 软性预拉） |
| `postgresql:18-alpine` | postgres:18-alpine | PostgreSQL 站点 |
| `redis:8.8-alpine` | redis:8.8-alpine | 缓存 |

`mirror-components.yml` 每周一自动刷新跟进上游 tag 漂移。

## CI（GitHub Actions）

- `build.yml`（PHP）：**每周六 02:00 UTC 自动重建受支持版本**（浮动 base 吃上游补丁）；手动 dispatch 可传 versions 过滤或点名 legacy 版本应急；推 tag `php-v*` 全量；`fail-fast: false` 互不阻塞
- `build-python.yml`（Python）：手动触发（versions 过滤）或推 tag `py-v*`；`3.15` 同时更新 `latest`
- `mirror-components.yml`（基础组件）：crane copy 官方镜像入命名空间；手动触发 / 每周一定时 / 改动本文件触发

**漏洞响应 SOP**：关注 php.net 安全公告 → dispatch build.yml 传受影响版本 → 当天出新镜像 → 面板端 detect `php -v` 补丁号对比修复版本，提示已部署站点重拉。
- 均为 buildx + QEMU 双架构；`GITHUB_TOKEN` 天然有 `packages:write`，无需配置 secret
- PHP mods 层 `EXT_DIR` 从父镜像运行时动态解析（与上游构建逻辑一致）

注意：PHP mods 层在 QEMU 上编译 arm64 较慢（单版本 2 小时量级），属预期。

## 使用

```bash
docker pull ghcr.io/ifreepanel/php-fpm:8.5-prod
docker run --rm ghcr.io/ifreepanel/php-fpm:8.5-prod php -m

docker pull ghcr.io/ifreepanel/python-fastapi:3.15
```

国内在线机可走加速前缀：`ghcr.1ms.run/ifreepanel/...`（或 `ghcr.nju.edu.cn`）。

本地调试单版本 PHP：`sh build-local.sh 8.5 amd64`（先把脚本内 IMAGE 换成你的命名空间）。

## 与 iFreePanel 的衔接

- `pull-images.sh` 镜像名切换：`bypanel/php-fpm:{v}-prod` → `ghcr.io/ifreepanel/php-fpm:{v}-prod`；Python 侧同理指向 `python-fastapi:3.15`
- 扩展矩阵事实源（`php-extension-matrix.json`）继续从 Dockerfiles/mods 解析，扩展增删改本仓库 Dockerfile 即可，一份文件喂构建 + 面板 UI
- 老版本 5.3/5.4/5.5 等不在 CI 矩阵，需要时把对应 Dockerfile 与版本加回

## 溯源

- PHP 构建源：linuxeye/docker-php-fpm @ 25387ab（2026-09-09），MIT License（见 LICENSE.md）
- 定制点：FROM 参数化（ARG PARENT_IMAGE）、容器内用户组与配置文件名调整、labels 指向本仓库
