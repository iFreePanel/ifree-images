# ifree-images

iFreePanel 的自建容器镜像仓库：**PHP-FPM 多版本运行时**（6 LTS）与 **Python-FastAPI 运行时底座**，全部 linux/amd64 + linux/arm64 双架构。

## 产物一览

### PHP-FPM —— `ghcr.io/iFreePanel/php-fpm:{版本}-prod`

基础配方基于 `linuxeye/docker-php-fpm`（MIT），在其上做了参数化与容器内配置定制。

| 版本 | base 层来源 | 说明 |
|---|---|---|
| 8.1 / 8.2 / 8.4 / 8.5 | 官方 `php:{v}-fpm-bookworm` | 全链自主，无上游依赖 |
| 5.6 / 7.4 | linuxeye 私造基础镜像（stretch/buster），CI 中 crane copy 导入 | 老版本基础层如实保留上游依赖，mods/prod 自主 |

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

## CI（GitHub Actions）

- `build.yml`（PHP）：手动触发（可传 versions 过滤，如 `8.5 8.4`）或推 tag `php-v*` 全量；6 版本矩阵并行，`fail-fast: false` 互不阻塞
- `build-python.yml`（Python）：手动触发（versions 过滤）或推 tag `py-v*`；`3.15` 同时更新 `latest`
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
