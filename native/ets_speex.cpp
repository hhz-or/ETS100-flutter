// ets_speex.dll — 16k mono speex encoder (quality 10 / CBR 84800 → 106B/frame)
// Built from the vendored speex sources in native-replica/third_party/speex.
#include <stdint.h>
#include <string.h>
#include "speex/speex.h"

#ifdef _WIN32
#define ETS_API __declspec(dllexport)
#else
#define ETS_API
#endif

extern "C" {

ETS_API int ets_speex_encode_size(int samples) {
    if (samples <= 0) return 0;
    const int frames = samples / 320;      // 20ms @16k
    return frames * 128 + 256;             // worst case per frame
}

ETS_API int ets_speex_encode(const int16_t* pcm, int samples, uint8_t* out, int outCap,
                             int* outLen, int* outFrames) {
    if (!pcm || !out || !outLen || samples < 320 || outCap <= 0) return -1;
    void* enc = speex_encoder_init(&speex_wb_mode);
    if (!enc) return -2;
    int q = 10, vbr = 0, rate = 16000, br = 84800, frameSize = 0;
    speex_encoder_ctl(enc, SPEEX_SET_QUALITY, &q);
    speex_encoder_ctl(enc, SPEEX_SET_VBR, &vbr);
    speex_encoder_ctl(enc, SPEEX_SET_BITRATE, &br);
    speex_encoder_ctl(enc, SPEEX_SET_SAMPLING_RATE, &rate);
    speex_encoder_ctl(enc, SPEEX_GET_FRAME_SIZE, &frameSize);
    if (frameSize != 320) { speex_encoder_destroy(enc); return -3; }

    SpeexBits bits;
    speex_bits_init(&bits);
    int used = 0, frames = 0;
    for (int off = 0; off + frameSize <= samples; off += frameSize) {
        speex_bits_reset(&bits);
        speex_encode_int(enc, (spx_int16_t*)(pcm + off), &bits);
        const int n = speex_bits_nbytes(&bits);
        if (used + n > outCap) break;
        speex_bits_write(&bits, (char*)(out + used), n);
        used += n;
        frames++;
    }
    speex_bits_destroy(&bits);
    speex_encoder_destroy(enc);
    *outLen = used;
    *outFrames = frames;
    return 0;
}

ETS_API int ets_speex_version() { return 121; }

} // extern "C"
