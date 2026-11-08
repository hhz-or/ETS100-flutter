# Speex（vendored）

本目录是 [Speex](https://gitlab.xiph.org/xiph/speex) 1.2 的 C 源码子集，
用于编译 `ets_speex.dll`（16 kHz 单声道宽带编码器，quality 10 / CBR 84800，106 字节/帧）。

- 许可证：BSD-3-Clause，版权归 Xiph.Org Foundation / Jean-Marc Valin 等 Speex 作者所有。
- 仅保留 `libspeex/` 与 `include/speex/`，未修改算法实现。
- 构建方式见 `native/build.ps1`。

BSD-3-Clause 许可证要点：允许在保留版权声明、条件列表和免责声明的前提下，
以源代码或二进制形式再分发；不得使用作者名义为衍生产品背书；软件按“原样”提供，
不附带任何明示或暗示担保。
