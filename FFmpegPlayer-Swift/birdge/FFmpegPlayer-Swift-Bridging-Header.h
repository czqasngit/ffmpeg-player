//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavfilter/avfilter.h>
#include <libavfilter/buffersrc.h>
#include <libavfilter/buffersink.h>
#include <libavutil/opt.h>
#include <libavutil/error.h>
#include <libswresample/swresample.h>
#include <libavutil/avutil.h>

static int READ_END_OF_FILE = AVERROR_EOF;
static int64_t PTS_INVALID = AV_NOPTS_VALUE;
static const uint8_t ** getPointer(AVFrame *frame) {
    return (const uint8_t **)frame->data;
}

#define GL_SILENCE_DEPRECATION
#include <OpenGL/gl3.h>
