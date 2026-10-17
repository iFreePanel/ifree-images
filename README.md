# ifreepanel-php

iFreePanel 品牌独立的 PHP-FPM 镜像构建仓库。构建源自 `linuxeye/docker-php-fpm`（MIT），已全量参数化并去除上游命名空间。

## 产物

`ghcr.io/<仓库owner>/php-fpm:{版本}-base / -mods / -prod`（linux/amd64 + linux/arm64）

| 版本 | base 层来源 | 说明 |
|---|---|---|
| 8.1 / 8.2 / 8.4 / 8.5 | 官方 `php:{v}-fpm-bookworm` | 全链自主，无上游依赖 |
| 5.6 / 7.4 | linuxeye 私造基础镜像（stretch/buster），CI 中 crane copy 导入 | 老版本基础层如实保留上游依赖，mods/prod 自主 |

三层语义（继承上游）：**base** = PHP 核心；**mods** = 预编译全部扩展（~70 个）；**prod** = composer + 运行时收尾。iFreePanel 面板与离线包只用 `-prod`。

## CI（GitHub Actions）

`.github/workflows/build.yml`：
- 手动触发（`workflow_dispatch`，可传 versions 过滤，如 `8.5 8.4`）或推 tag `php-v*` 全量构建
- buildx + QEMU 双架构；`GITHUB_TOKEN` 天然有 `packages:write`，无需配置 secret
- mods 层 `EXT_DIR` 从父镜像运行时动态解析（与上游构建逻辑一致）

注意：mods 层在 QEMU 上编译 arm64 较慢（单版本可达数十分钟），属预期；`fail-fast: false` 各版本互不阻塞。

## 使用

```bash
# 1. 在 GitHub 建仓库（名随意，如 ifreepanel-php），push 本目录
# 2. Actions → build-php → Run workflow（versions 填 8.5 先试一个）
# 3. 首次推送后：GitHub → Packages → php-fpm → Package settings → Public
# 4. 拉取验证
docker pull ghcr.io/<owner>/php-fpm:8.5-prod
docker run --rm ghcr.io/<owner>/php-fpm:8.5-prod php -m
```

本地调试单版本：`sh build-local.sh 8.5 amd64`（先把脚本内 IMAGE 换成你的命名空间）。

## 与 iFreePanel 的衔接

- `pull-images.sh` 镜像名切换：`bypanel/php-fpm:{v}-prod` → `ghcr.io/<owner>/php-fpm:{v}-prod`
- 扩展矩阵事实源（`php-extension-matrix.json`）继续从 Dockerfiles/mods 解析，扩展增删改本仓库 Dockerfile 即可，一份文件喂构建 + 面板 UI
- 老版本 5.3/5.4/5.5 等不在 CI 矩阵，需要时把对应 Dockerfile 与版本加回

## 溯源

- 构建源：linuxeye/docker-php-fpm @ 25387ab（2026-09-09），MIT License（见 LICENSE.md）
- 与上游差异：FROM 参数化（ARG PARENT_IMAGE）、命名空间品牌替换（用户组/ini 文件名/entrypoint 生成文件名）、labels 作者改为本仓库
