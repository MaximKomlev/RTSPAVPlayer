//
//  RTSPSegmenter.m
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 1/23/19.
//  Copyright © 2019 Maxim Komlev. All rights reserved.
//

#import <libavformat/avformat.h>
#import <libavutil/timestamp.h>

#import "RTSPSegmenter.h"
#import "SegmentsManager.h"
#import "definitions.h"
#import "stringutils.h"
#import "RTSPSegmentStreamer.h"

struct segment_context {
    const char *url;
    uint writable;
};

#define buffer_size 4096

static void log_packet(const AVFormatContext *fmt_ctx, const AVPacket *pkt, const char *tag) {
    AVRational *time_base = &fmt_ctx->streams[pkt->stream_index]->time_base;
    printf("%s: pts:%s pts_time:%s dts:%s dts_time:%s duration:%s duration_time:%s stream_index:%d\n",
           tag,
           av_ts2str(pkt->pts),
           av_ts2timestr(pkt->pts, time_base),
           av_ts2str(pkt->dts),
           av_ts2timestr(pkt->dts, time_base),
           av_ts2str(pkt->duration),
           av_ts2timestr(pkt->duration, time_base),
           pkt->stream_index);
}

static int writeStream(void* opaque, uint8_t* buf, int buf_size) {
    struct segment_context *ctx = (struct segment_context *)opaque;
    NSString *url = [NSString stringWithUTF8String:(char *)ctx->url];
    BOOL isWritable = (BOOL)ctx->writable;
    [[SegmentsManager instance] writeStreamForUrl:url writable:isWritable data:buf length:buf_size];
    return buf_size;
}

static int readStream(void *opaque, uint8_t *buf, int buf_size) {
    struct segment_context *ctx = (struct segment_context *)opaque;
    NSString *url = [NSString stringWithUTF8String:(char *)ctx->url];
    BOOL isWritable = (BOOL)ctx->writable;
    NSData *data = [[SegmentsManager instance] readStreamForUrl:url writable:isWritable length:buf_size];
    
    uint len = data.length;
    if (len) {
        memcpy(buf, data.bytes, len);
        return len;
    }
    return AVERROR_EOF;
}

static int64_t seekStream(void *opaque, int64_t offset, int whence) {
    struct segment_context *ctx = (struct segment_context *)opaque;
    NSString *url = [NSString stringWithUTF8String:(char *)ctx->url];
    BOOL isWritable = (BOOL)ctx->writable;
    [[SegmentsManager instance] seekStreamForUrl:url writable:isWritable toPosition:(whence + offset)];
    return 0;
}

static AVIOContext * openStream(const char *url, int flags) {
    struct segment_context *ctx = malloc(sizeof(struct segment_context));
    ctx->url = url;

    uint8_t *ioBuffer = av_malloc(buffer_size);
    uint write_flag = 0;
    if (AVIO_FLAG_WRITE & flags) {
        write_flag = 1;
    }
    ctx->writable = write_flag;

    NSString *urlStr = [NSString stringWithUTF8String:(char *)ctx->url];
    [[SegmentsManager instance] startStreamForUrl:urlStr writable:(BOOL)write_flag];

    return avio_alloc_context(ioBuffer, buffer_size, write_flag, ctx, &readStream, &writeStream, &seekStream);
}

static int io_open(struct AVFormatContext *s, AVIOContext **pb, const char *url,
                   int flags, AVDictionary **options) {
    AVIOContext *avioCtx = openStream(url, flags);
    avioCtx->seekable = AVIO_SEEKABLE_NORMAL;
    *pb = avioCtx;
    if (!avioCtx) {
        return -1;
    }
    return 0;
}

static void io_close(struct AVFormatContext *s, AVIOContext *pb) {
    struct segment_context *ctx = (struct segment_context *)pb->opaque;
    NSString *url = [NSString stringWithUTF8String:(char *)ctx->url];
    BOOL isWritable = (BOOL)ctx->writable;
    [[SegmentsManager instance] stopStreamForUrl:url writable:isWritable];
//    if (isWritable) {
//        fprintf(stdout, "Stop writable stream %s", ctx->url);
//    } else {
//        fprintf(stdout, "Stop readable stream %s", ctx->url);
//    }
    free(pb->opaque);
    av_free(pb->buffer);
    avio_context_free(&pb);
}

static int interrupt_cb(void *ctx) {
    return 0;
}

@implementation RTSPSegmenter {
    NSURL *_sessionUrl;
    NSLock *_locker;
    NSDictionary *_options;
}

@synthesize isStopped = _isStopped;

+ (void)ffmpegInitialization {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        avformat_network_init();
    });
}

- (id)initWithUrl:(NSURL *)url {
    if (self = [super init]) {
        [RTSPSegmenter ffmpegInitialization];
        
        _isStopped = TRUE;
        _sessionUrl = url;
        _locker = [NSLock new];
    }
    return self;
}

- (id)initWithUrl:(NSURL *_Nonnull)url withOptions:(NSDictionary *)options {
    if (self = [self initWithUrl:url]) {
        _options = options;
    }
    return self;
}

- (void)start {
    self.isStopped = FALSE;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self startLoading];
    });
}

- (void)stop {
    self.isStopped = TRUE;
}

- (BOOL)isStopped {
    __block BOOL result = FALSE;
    [self synchronize:^{
        result = self->_isStopped;
    }];
    return result;
}

- (void)setIsStopped:(BOOL)isStopped {
    [self synchronize:^{
        self->_isStopped = isStopped;
    }];
}

#pragma mark - Helpers

- (void)startLoading {
    AVDictionary *opts = NULL;
    
    AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL;
    const char *in_filename, *out_formatname, *out_seg_formatname;
    int ret, i;
    
    in_filename  = [_sessionUrl.absoluteString UTF8String];
    out_formatname = [@"segment" UTF8String];
    out_seg_formatname = [@"mp4" UTF8String];
    
    // in options
    av_dict_set(&opts, "rtsp_transport", "tcp", 0); // !!!
    av_dict_set_int(&opts, "analyzeduration", 5, 0);

    // out options
    av_dict_set(&opts, "f", out_formatname, 0);
    av_dict_set(&opts, "segment_format", out_seg_formatname, 0);
    av_dict_set(&opts, "segment_time", "4", 0);
    av_dict_set(&opts, "reset_timestamps", "1", 0);
    av_dict_set(&opts, "segment_time_delta", "0.5", 0);
//    av_dict_set(&opts, "segment_atclocktime", "1", 0);
//    av_dict_set_int(&opts, "increment_tc", 1, 0);
    av_dict_set(&opts, "segment_format_options", "fflags=+discardcorrupt+genpts+sortdts+shortest", 0);
//    av_dict_set(&opts, "segment_format_options", "movflags=+faststart", 0); //

    //    av_dict_set_int(&opts, "frames", 5, 0);
    //    av_dict_set_int(&opts, "sync-av-start", 1, 0);
    //    av_dict_set_int(&opts, "infbuf", 1, 0);
    //    av_dict_set_int(&opts, "avioflags", 32, 0);
    //    av_dict_set(&opts, "probesize", "32", 0);
    //    av_dict_set_int(&opts, "flush_packets", 1, 0);
    //
    //    av_dict_set_int(&opts, "packet-buffering", 0, 0);
    //    av_dict_set_int(&opts, "framedrop", 1, 0);
    //    av_dict_set_int(&opts, "max_delay", 0, 0);
    //    av_dict_set(&opts, "flags", "low_delay", 0);
    //    av_dict_set(&opts, "sync", "audio", 0);
    //    av_dict_set_int(&opts, "skip_loop_filter", 0, 0);
    //    av_dict_set_int(&opts, "skip_frame", 0, 0);
    //    av_dict_set(&opts, "fflags", "discardcorrupt+nobuffer", 0);
    //    av_dict_set(&opts, "ec", "favor_inter", 0);
    
    while (TRUE) {
        if ((ret = avformat_open_input(&ifmt_ctx, in_filename, 0, &opts)) < 0 || self.isStopped) {
            if (ret < 0) {
                fprintf(stderr, "Could not open input file '%s', error: %s", in_filename, av_err2str(ret));
            }
            break;
        }
        
        if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0 || self.isStopped) {
            if (ret < 0) {
                fprintf(stderr, "Failed to retrieve input stream information, error: %s", av_err2str(ret));
            }
            break;
        }
        av_dump_format(ifmt_ctx, 0, in_filename, 0);
        if (!(ofmt_ctx = avformat_alloc_context()) || self.isStopped) {
            ret = AVERROR(ENOMEM);
            fprintf(stderr, "Could not create output context, error: %s\n", av_err2str(ret));
            break;
        }
        NSMutableString *memoryId = [NSMutableString stringWithString:randomString(16)];
        [memoryId appendString:@"%d.mp4"];
        if ((ret = avformat_alloc_output_context2(&ofmt_ctx, NULL, out_formatname, [memoryId cStringUsingEncoding:NSUTF8StringEncoding]) < 0) || self.isStopped) {
            if (ret < 0) {
                fprintf(stderr, "Could not create output context, error: %s\n", av_err2str(ret));
            }
            break;
        }
        
        ofmt_ctx->flags = AVFMT_FLAG_CUSTOM_IO;
        ofmt_ctx->interrupt_callback.callback = &interrupt_cb;
        ofmt_ctx->interrupt_callback.opaque = ofmt_ctx;
        ofmt_ctx->io_open = &io_open;
        ofmt_ctx->io_close = &io_close;
//        ofmt_ctx->debug = FF_FDEBUG_TS;
        
        int stream_index = 0;
        int *stream_mapping = NULL;
        int stream_mapping_size = 0;
        
        stream_mapping_size = ifmt_ctx->nb_streams;
        if (!(stream_mapping = av_mallocz_array(stream_mapping_size, sizeof(*stream_mapping)))) {
            ret = AVERROR(ENOMEM);
            break;
        }
        
        for (i = 0; i < ifmt_ctx->nb_streams; i++) {
            AVStream *in_stream = ifmt_ctx->streams[i];
            AVCodecParameters *in_codecpar = in_stream->codecpar;
            
            if (in_codecpar->codec_type != AVMEDIA_TYPE_AUDIO &&
                in_codecpar->codec_type != AVMEDIA_TYPE_VIDEO &&
                in_codecpar->codec_type != AVMEDIA_TYPE_SUBTITLE) {
                stream_mapping[i] = -1;
                continue;
            }

            stream_mapping[i] = stream_index++;
            
            if ((ret = [self addOutStream:ofmt_ctx basedOn:in_stream]) < 0 || self.isStopped) {
                if (ret < 0) {
                    fprintf(stderr, "Failed to copy context from input to output stream codec context, error: %s\n", av_err2str(ret));
                }
                break;
            }
        }
        
        if (ret == 0 && !self.isStopped) {
            if ((ret = avformat_write_header(ofmt_ctx, &opts)) < 0 || self.isStopped) {
                if (ret < 0) {
                    fprintf(stderr, "Error occurred when opening output file, error: %s\n", av_err2str(ret));
                } else {
                    ret = AVERROR_UNKNOWN;
                }
                break;
            }
        }
        
        while (ret == 0 && !self.isStopped) {
            if (![self makeMuxingFrom:ifmt_ctx to:ofmt_ctx stream_mapping:stream_mapping stream_mapping_size:stream_mapping_size]) {
                break;
            }
        }
        if (ret == 0 && !self.isStopped) {
            av_write_trailer(ofmt_ctx);
        }
        
        break;
    }
    
    av_dict_free(&opts);
    
    avformat_close_input(&ifmt_ctx);
    avformat_free_context(ofmt_ctx);
    
    if (ret < 0 && ret != AVERROR_EOF) {
        fprintf(stderr, "Error occurred: %s\n", av_err2str(ret));
    }
}

/* Add an output stream. */
- (int)addOutStream:(AVFormatContext *)oc basedOn:(AVStream *)in_stream {
    int ret = 0;
    
    AVCodecParameters *in_codecpar = in_stream->codecpar;
    
    AVStream *out_stream = avformat_new_stream(oc, NULL);
    if (!out_stream) {
        fprintf(stderr, "Could not allocate stream\n");
        return -1;
    }
    
    out_stream->id = in_stream->id;
    
    if ((ret = avcodec_parameters_copy(out_stream->codecpar, in_codecpar)) < 0) {
        return ret;
    }
    out_stream->codecpar->codec_tag = 0;

    return ret;
}

/* remuxing */
- (BOOL)makeMuxingFrom:(AVFormatContext *)ifmt_ctx to:(AVFormatContext *)ofmt_ctx stream_mapping:(int *)stream_mapping stream_mapping_size:(int)stream_mapping_size {
    AVPacket pkt;
    AVStream *in_stream, *out_stream;
    int ret = av_read_frame(ifmt_ctx, &pkt);

    in_stream  = ifmt_ctx->streams[pkt.stream_index];
    if (pkt.stream_index < stream_mapping_size &&
        stream_mapping[pkt.stream_index] >= 0) {
        pkt.stream_index = stream_mapping[pkt.stream_index];
        out_stream = ofmt_ctx->streams[pkt.stream_index];
        //log_packet(ifmt_ctx, &pkt, "in");

        /* copy packet */
        pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        pkt.duration = av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
        pkt.pos = -1;
        
        //log_packet(ofmt_ctx, &pkt, "out");
        if (pkt.dts != AV_NOPTS_VALUE) {
            ret = av_interleaved_write_frame(ofmt_ctx, &pkt);
        }
    }
    av_packet_unref(&pkt);

    if (ret < 0) {
        fprintf(stderr, "Error muxing packet, error: %s\n", av_err2str(ret));
    }

    return ret < 0 ? FALSE : TRUE;
}

#pragma mark - Helpers (Sync)

- (void)synchronize:(synchronized_block)block {
    [_locker lock]; {
        block();
    }
    [_locker unlock];
}

@end
