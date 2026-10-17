#!/bin/sh
# 本地单版本构建（dogfooding / CI 失败排查用）
# 用法: sh build-local.sh <版本> [amd64|arm64]   例: sh build-local.sh 8.5 amd64
set -eu
V=${1:?usage: build-local.sh <版本> [amd64|arm64]}
ARCH=${2:-amd64}
case "$ARCH" in
  amd64) PLATFORM=linux/amd64; GOARCH=x86_64 ;;
  arm64) PLATFORM=linux/arm64; GOARCH=aarch64 ;;
  *) echo "arch 仅支持 amd64|arm64"; exit 2 ;;
esac
IMAGE=ghcr.io/iFreeshine/php-fpm      # 品牌 org 建好后改为 ghcr.io/ifreepanel/php-fpm

case "$V" in
  5.6) PARENT=ghcr.io/iFreeshine/php-fpm-5.6:stretch ;;
  7.4) PARENT=ghcr.io/iFreeshine/php-fpm-7.4:buster ;;
  *)   PARENT=$IMAGE:$V-base ;;
esac

# base（仅 8.x 需要本地构建；5.6/7.4 直接 pull 导入的基础镜像）
case "$V" in
  8.*) docker build --platform "$PLATFORM" -f Dockerfiles/base/Dockerfile-$V -t $IMAGE:$V-base Dockerfiles/base ;;
  *)   docker pull --platform "$PLATFORM" "$PARENT" ;;
esac

EXT_DIR=$(docker run --rm --platform "$PLATFORM" --entrypoint=php "$PARENT" -r 'echo ini_get("extension_dir");')
echo "EXT_DIR=$EXT_DIR"

docker build --platform "$PLATFORM" \
  --build-arg PARENT_IMAGE=$PARENT --build-arg EXT_DIR=$EXT_DIR \
  -f Dockerfiles/mods/Dockerfile-$V -t $IMAGE:$V-mods Dockerfiles/mods

docker build --platform "$PLATFORM" \
  --build-arg PARENT_IMAGE=$IMAGE:$V-mods \
  -f Dockerfiles/prod/Dockerfile-$V -t $IMAGE:$V-prod Dockerfiles/prod

docker run --rm --platform "$PLATFORM" $IMAGE:$V-prod php -m | head -20
