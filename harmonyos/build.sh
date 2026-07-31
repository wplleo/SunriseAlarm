#!/bin/bash
# 晨光闹钟 HarmonyOS NEXT 命令行编译脚本
# 前置条件：已安装 DevEco Studio（含 HarmonyOS SDK）或独立 Command Line Tools，
#          且 ohpm / hvigor / node 已在 PATH 中。
#
# 用法：
#   1. 将 local.properties.example 复制为 local.properties 并填入本机 SDK 路径
#   2. chmod +x build.sh
#   3. ./build.sh debug      # 编译 debug HAP（开发/模拟器用）
#      ./build.sh app        # 编译并打包 APP 发布包（需已配置签名证书）
set -e

MODE="${1:-debug}"
PRODUCT="default"

echo "==> [1/3] 安装依赖 (ohpm install)"
ohpm install

echo "==> [2/3] 编译 HAP (assembleHap, buildMode=$MODE)"
if [ -f "./hvigorw" ]; then
  ./hvigorw assembleHap --mode module -p product=$PRODUCT -p buildMode=$MODE
else
  hvigor assembleHap --mode module -p product=$PRODUCT -p buildMode=$MODE
fi

if [ "$MODE" = "app" ]; then
  echo "==> [3/3] 打包 APP (assembleApp, release)"
  if [ -f "./hvigorw" ]; then
    ./hvigorw assembleApp --mode project -p product=$PRODUCT -p buildMode=release
  else
    hvigor assembleApp --mode project -p product=$PRODUCT -p buildMode=release
  fi
  echo "==> APP 产物见: build/outputs/default/  (需签名后才能在真机安装)"
else
  echo "==> HAP 产物见: entry/build/default/outputs/default/entry-default-$MODE-signed.hap"
fi
