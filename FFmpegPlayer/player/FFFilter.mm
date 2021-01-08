//
//  FFFilter.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/5.
//

#import "FFFilter.h"

/// 打印属于obj的所有AVOptions信息
static void av_print_options(void *obj) {
    /// 这里的obj实际上是一个第一个变量是AVClass *的指针
    /// 类似如下指针
    /**
     struct AVFilterContext {
         const AVClass *av_class;
     }
     */
    /// 所以要打印AVClass的信息,需要将obj转变成一个指针的指针
    /// obj对于const AVClass *av_class;来说它就是一个指针的指针
    /// 再通过取指针的指针的值,就得到了AVClass *av_class的地址值
    if(!obj) return;
    const AVOption *opt = NULL;
    while ((opt = av_opt_next(obj, opt))) {
        AVClass *av_class = *(AVClass **)obj;
        printf("AVClass: %s, AVOption: %s, type: %d \n", av_class->class_name, opt->name, opt->type);
    }
}
/// 打印obj中所有的AVOptions以及children中的AVOptions
static void av_print_obj_all_options(void *obj) {
    void *child = NULL;
    while ((child = av_opt_child_next(obj, child))) {
        av_print_options(child);
    }
    av_print_options(obj);
}


@interface FFFilter()
@end
@implementation FFFilter {
    AVFormatContext *formatContext;
    AVCodecContext *codecContext;
    AVStream *stream;
    AVPixelFormat fmt;
    AVFilterGraph *graph;
    AVFilterContext *bufferContext;
    AVFilterContext *bufferSinkContext;
}

- (void)dealloc {
    if(graph) avfilter_graph_free(&graph);
    if(bufferContext) avfilter_free(bufferContext);
    if(bufferSinkContext) avfilter_free(bufferSinkContext);
}
- (instancetype)initWithCodecContext:(AVCodecContext *)codecContext
                       formatContext:(AVFormatContext *)formatContext
                              stream:(AVStream *)stream
                                 fmt:(AVPixelFormat)fmt {
    self = [super init];
    if (self) {
        self->codecContext = codecContext;
        self->formatContext = formatContext;
        self->stream = stream;
        self->fmt = fmt;
    }
    return self;
}

- (BOOL)setup:(AVPixelFormat)inputFormat {
    /// 每一个graph都有一个输入与输出,中间连接多个filter
    AVFilterInOut *inputs = avfilter_inout_alloc();
    AVFilterInOut *outputs = avfilter_inout_alloc();
    AVRational time_base = stream->time_base;
    const AVFilter *buffer = avfilter_get_by_name("buffer");
    const AVFilter *bufferSink = avfilter_get_by_name("buffersink");
    int ret = 0;
    enum AVPixelFormat format[] = {self->fmt};  //想要转换的格式
    if(!buffer || !bufferSink) {
        NSLog(@"get buffer and buffersink filter failed.");
        goto fail;
    }
    graph = avfilter_graph_alloc();
    char args[512];
    /// 在创建buffer filter的时候传入一个字符串作为初始化时的参数
    /// 这里需要注意的是对应的变量的参数不能是AV_OPT_TYPE_BINARY这种类型
    /// AV_OPT_TYPE_BINARY需要单独设置,因为它的数据需要是一个指针
    snprintf(args, sizeof(args), "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
             codecContext->width,
             codecContext->height,
             inputFormat,
             time_base.num,
             time_base.den,
             codecContext->sample_aspect_ratio.num,
             codecContext->sample_aspect_ratio.den);
    ret = avfilter_graph_create_filter(&bufferContext, buffer, "in", args, NULL, graph);
    av_print_obj_all_options(bufferContext);
    if(ret < 0) {
        NSLog(@"初始化buffer filter失败");
        goto fail;
    }
    ret = avfilter_graph_create_filter(&bufferSinkContext, bufferSink, "out", NULL, NULL, graph);
    av_print_obj_all_options(bufferSinkContext);
    /**
     pix_fmts在buffersink.c中定义了一个AVFilter名称为buffersink,添加了一个AVOption为pix_fmts
     static const AVOption buffersink_options[] = {
         { "pix_fmts", "set the supported pixel formats", OFFSET(pixel_fmts), AV_OPT_TYPE_BINARY, .flags = FLAGS },
         { NULL },
     };
     */
    /// 这里的pix_fmts不能通过字符串的形式初始化,因为他的类型是一个AV_OPT_TYPE_BINARY
    /// pix_fmts定义如下: enum AVPixelFormat *pixel_fmts; 它是一个指针
    /// 设置buffersink出口的数据格式是RGB24
    ret = av_opt_set_bin(bufferSinkContext, "pix_fmts", (uint8_t *)&format, sizeof(self->fmt), AV_OPT_SEARCH_CHILDREN);
    if (ret < 0) {
        NSLog(@"Set pix_fmts value to buffersink class error.");
        goto fail;
    }
    inputs->name = av_strdup("out");
    inputs->filter_ctx = bufferSinkContext;
    inputs->pad_idx = 0;
    inputs->next = NULL;
    
    outputs->name = av_strdup("in");
    outputs->filter_ctx = bufferContext;
    outputs->pad_idx = 0;
    outputs->next = NULL;
    
    /// 使用字符串解析来添加filter到graph中
    /// 这里没有额外的filter在中间连接,所以传入"null"
    /// 整个graph中有两个filter,buffer(解码数据的输入filter),buffersink(获取解码数据的filter)
    /**
     AVFilter ff_vf_null = {
         .name        = "null",
         .description = NULL_IF_CONFIG_SMALL("Pass the source unchanged to the output."),
         .inputs      = avfilter_vf_null_inputs,
         .outputs     = avfilter_vf_null_outputs,
     };
     */
    /// filters: 参数传入一个null名称的filter
    ret = avfilter_graph_parse_ptr(graph, "null", &inputs, &outputs, NULL);
    if(ret < 0) {
        NSLog(@"add filter inputs/outputs to graph failed.");
        goto fail;
    }
    ret = avfilter_graph_config(graph, NULL);
    if(ret < 0) {
        NSLog(@"graph check failed.");
        goto fail;
    }
    goto success;
fail:
    if(inputs) avfilter_inout_free(&inputs);
    if(outputs) avfilter_inout_free(&outputs);
    return NO;
success:
    /// free inputs/outputs after avfilter_graph_parse_ptr
    if(inputs) avfilter_inout_free(&inputs);
    if(outputs) avfilter_inout_free(&outputs);
    NSLog(@"初始化AVFilter完成.");
    return YES;
}

- (BOOL)getTargetFormatFrameWithInputFrame:(AVFrame *)inputFrame
                               outputFrame:(AVFrame **)outputFrame {
    if(!graph) {
        if(![self setup:(enum AVPixelFormat)inputFrame->format]) return false;
    }
    int ret = av_buffersrc_add_frame(bufferContext, inputFrame);
    if(ret < 0) {
        NSLog(@"add frame to buffersrc failed.");
        goto fail;
    }
    ret = av_buffersink_get_frame(bufferSinkContext, *outputFrame);
    if(ret < 0) {
        goto fail;
    }
    return YES;
fail:
    return NO;
}
@end
