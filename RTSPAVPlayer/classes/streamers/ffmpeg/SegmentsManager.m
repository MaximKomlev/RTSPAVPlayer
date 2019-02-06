//
//  SegmentsManager.m
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 1/23/19.
//  Copyright © 2019 Maxim Komlev. All rights reserved.
//

#import "definitions.h"
#import "SegmentsManager.h"
#import "RTSPSegmentStreamer.h"

@interface SegmentsManager () {
    NSLock *_locker;
    NSMutableDictionary<NSString *, RTSPSegmentStreamer *> *_streams;
}
@end

@implementation SegmentsManager

+ (SegmentsManager *)instance {
    static dispatch_once_t onceToken;
    static SegmentsManager *instance;
    dispatch_once(&onceToken, ^{
        instance = [SegmentsManager new];
    });
    return instance;
}

- (id)init {
    if (self = [super init]) {
        _locker = [NSLock new];
        _streams = [NSMutableDictionary new];
    }
    return self;
}

- (void)dealloc {
    [self stopAllStreams];
}

#pragma mark - SegmentsManager public interface

- (void)startStreamForUrl:(NSString *)url writable:(BOOL)writable {
    [self synchronize:^{
        if (!self->_streams[url]) {
            self->_streams[url] = [[RTSPSegmentStreamer alloc] initWithUrl:[NSURL fileURLWithPath:url]];
            [self.delegate segmentStarted:self->_streams[url]];
        }
        [self->_streams[url] createInterfaceFor:writable];
    }];
}

- (NSInteger)writeStreamForUrl:(NSString *)url writable:(BOOL)writable data:(const uint8_t *)buffer length:(NSUInteger)len {
    __block NSInteger result = 0;
    [self synchronize:^{
        RTSPSegmentStreamer *streamer = self->_streams[url];
        if (streamer) {
            result = [[streamer getInterfaceFor:writable] writeData:buffer length:len];
            [self.delegate segmentUpdated:streamer];
        }
    }];
    return result;
}

- (NSData *)readStreamForUrl:(NSString *)url writable:(BOOL)writable length:(NSUInteger)len {
    __block NSData *result = 0;
    [self synchronize:^{
        RTSPSegmentStreamer *streamer = self->_streams[url];
        if (streamer) {
            result = [[streamer getInterfaceFor:writable] readData:len];
        }
    }];
    return result;
}

- (void)seekStreamForUrl:(NSString *)url writable:(BOOL)writable toPosition:(NSUInteger)position {
    [self synchronize:^{
        RTSPSegmentStreamer *streamer = self->_streams[url];
        if (streamer) {
            [[streamer getInterfaceFor:writable] seekTo:position];
        }
    }];
}

- (void)stopAllStreams {
    [self synchronize: ^{
        [self->_streams removeAllObjects];
        [self.delegate segmentsRemoved];
    }];
}

- (void)stopStreamForUrl:(NSString * _Nonnull)url writable:(BOOL)writable {
    [self synchronize: ^{
        RTSPSegmentStreamer *streamer = self->_streams[url];
        [[streamer getInterfaceFor:writable] finish];
        if ([streamer isReady]) {
            [self->_streams removeObjectForKey:url];

            //[streamer dumpDataToFile];
            [self.delegate segmentFinished:streamer];
            [self.delegate segmentRemoved:streamer];
        }
    }];
}

#pragma mark - Helpers

- (void)synchronize:(synchronized_block)block {
    [_locker lock]; {
        block();
    }
    [_locker unlock];
}

@end
