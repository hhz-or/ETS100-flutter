#!/usr/bin/env bash
# 构建 speex 编码库（Linux / macOS），产物：
#   assets/native/libets_speex.so   (Linux)
#   assets/native/libets_speex.dylib (macOS)
#
# 依赖：gcc/g++（Linux）或 clang/clang++（macOS），以及 make 工具链。
# 用法：bash native/build.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPX="$ROOT/native/speex"
OUT="$ROOT/assets/native"
OBJ="$ROOT/build/native-unix"
mkdir -p "$OUT" "$OBJ"
CC="${CC:-cc}"
CXX="${CXX:-c++}"

CFLAGS=(-O2 -fPIC -DHAVE_CONFIG_H -I"$SPX/include" -I"$SPX/libspeex")
objects=()
for src in "$SPX"/libspeex/*.c; do
  obj="$OBJ/$(basename "${src%.c}").o"
  "$CC" "${CFLAGS[@]}" -c "$src" -o "$obj"
  objects+=("$obj")
done
"$CXX" -O2 -fPIC -I"$SPX/include" -I"$SPX/libspeex" -c "$ROOT/native/ets_speex.cpp" -o "$OBJ/ets_speex.o"

if [[ "$(uname -s)" == "Darwin" ]]; then
  "$CXX" -dynamiclib -o "$OUT/libets_speex.dylib" "$OBJ/ets_speex.o" "${objects[@]}" -lm
  echo "已生成 $OUT/libets_speex.dylib"
else
  "$CXX" -shared -o "$OUT/libets_speex.so" "$OBJ/ets_speex.o" "${objects[@]}"
  echo "已生成 $OUT/libets_speex.so"
fi

# Android（需 NDK）示例：
#   $CC 需替换为 $NDK/toolchains/llvm/prebuilt/<host>/bin/aarch64-linux-android21-clang
#   产物放到 android/app/src/main/jniLibs/arm64-v8a/libets_speex.so
