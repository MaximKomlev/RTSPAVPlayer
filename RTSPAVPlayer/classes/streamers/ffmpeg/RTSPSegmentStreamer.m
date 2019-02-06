
#import "RTSPSegmentStreamer.h"
#import "definitions.h"
#import "stringutils.h"

@interface ReadableWritableSegmentStreamer () {
    NSInteger _offset;
    dispatch_queue_t _queue;
    BOOL _isFinished;
}

- (BOOL)isFinished;

@end

@interface RTSPSegmentStreamer () <NSStreamDelegate> {
    NSMutableData *_stream;
    dispatch_queue_t _queue;
    NSLock *_locker;
    NSMutableDictionary<NSNumber *, dispatch_block_t> *_tasks;
    
    ReadableWritableSegmentStreamer *_writeInterface;
    ReadableWritableSegmentStreamer *_readInterface;
}

- (id)init;

- (NSInteger)writeData:(const uint8_t *)buffer at:(NSUInteger)position length:(NSUInteger)length;
- (NSData *)readDataAt:(NSUInteger)position length:(NSUInteger)length;

@end

@implementation ReadableWritableSegmentStreamer

- (instancetype)init {
    if (self = [super init]) {
        _queue = dispatch_queue_create("_ReadableWritableSegmentStreamer_", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (instancetype)initWithStreamer:(RTSPSegmentStreamer *_Nonnull)stream {
    if (self = [self init]) {
        _stream = stream;
        _isFinished = FALSE;
    }
    return self;
}

- (NSInteger)writeData:(const uint8_t *)buffer length:(NSUInteger)length {
    dispatch_sync(_queue, ^{
        [self->_stream writeData:buffer at:self->_offset length:length];
        self->_offset += length;
    });
    return length;
 }

- (NSData *)readData:(NSUInteger)length {
    __block NSData *data = NULL;
    dispatch_sync(_queue, ^{
        data = [self->_stream readDataAt:self->_offset length:length];
        self->_offset += data.length;
    });
    return data;
}

- (void)seekTo:(NSUInteger)position {
    dispatch_sync(_queue, ^{
        self->_offset = position;
    });
}

- (void)finish {
    dispatch_sync(_queue, ^{
        self->_isFinished = TRUE;
    });
}

- (BOOL)isFinished {
    __block BOOL result = FALSE;
    dispatch_sync(_queue, ^{
        result = self->_isFinished;
    });
    return result;
}

@end

@implementation RTSPSegmentStreamer

@synthesize delegate;
@synthesize sessionUrl = _sessionUrl;

static NSString *_identificatorName = @"streamId";

- (instancetype)init {
    if (self = [super init]) {
        _locker = [NSLock new];
        _tasks = [NSMutableDictionary new];
        _queue = dispatch_queue_create("_SegmentStreamer_", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (instancetype)initWithUrl:(NSURL *)url {
    if (self = [self init]) {
        _sessionUrl = url;
        _stream = [NSMutableData new];
    }
    return self;
}

#pragma mark - Request public interface

- (void)performRequest:(NSDictionary<NSString *, NSObject *> * _Nullable)params forAVLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    __weak typeof(self) weakSelf = self;
    
    __block dispatch_block_t block = dispatch_block_create(0, ^{
        if (!(dispatch_block_testcancel(block) && loadingRequest.isCancelled)) {
            if (loadingRequest.contentInformationRequest) {
                if ([weakSelf.delegate respondsToSelector:@selector(responseHeader:withData:forLoadingRequest:)]) {
                    NSInteger length = [weakSelf dataLength];
                    NSDictionary<NSString *, NSObject *> *header = @{@"MIMEType"        : @"video/mp4",
                                                                     @"ContentLength"   : [NSNumber numberWithLongLong:length]};
                    [weakSelf.delegate responseHeader:weakSelf withData:header forLoadingRequest:loadingRequest];
                }
            } else if (loadingRequest.dataRequest.requestsAllDataToEndOfResource) {
                if ([weakSelf.delegate respondsToSelector:@selector(responseBody:withData:forLoadingRequest:)]) {
                    NSInteger requestedOffset = loadingRequest.dataRequest.requestedOffset;
                    NSInteger requestedLength = [weakSelf dataLength] - loadingRequest.dataRequest.requestedOffset;
                    [weakSelf.delegate responseBody:weakSelf withData:[weakSelf readDataForRange:NSMakeRange(requestedOffset, requestedLength)] forLoadingRequest:loadingRequest];
                }
                if ([weakSelf.delegate respondsToSelector:@selector(responseEnd:forLoadingRequest:withError:)]) {
                    [weakSelf.delegate responseEnd:weakSelf forLoadingRequest:loadingRequest withError:NULL];
                }
            } else if (loadingRequest.dataRequest) {
                NSInteger requestedOffset = loadingRequest.dataRequest.requestedOffset;
                NSInteger requestedLength = loadingRequest.dataRequest.requestedLength;
                if ([weakSelf.delegate respondsToSelector:@selector(responseBody:withData:forLoadingRequest:)]) {
                    [weakSelf.delegate responseBody:weakSelf withData:[weakSelf readDataForRange:NSMakeRange(requestedOffset, requestedLength)] forLoadingRequest:loadingRequest];
                }
                if ([weakSelf.delegate respondsToSelector:@selector(responseEnd:forLoadingRequest:withError:)]) {
                    [weakSelf.delegate responseEnd:weakSelf forLoadingRequest:loadingRequest withError:NULL];
                }
            }
        }
        [weakSelf cancelRequestFor:loadingRequest];
    });

    dispatch_async(_queue, block);
    
    [self synchronize:^{
        NSNumber *key = [NSNumber numberWithUnsignedInteger:loadingRequest.hash];
        self->_tasks[key] = block;
    }];
}

- (void)cancelRequestFor:(AVAssetResourceLoadingRequest *)loadingRequest {
    [self synchronize:^{
        NSNumber *key = [NSNumber numberWithUnsignedInteger:loadingRequest.hash];
        dispatch_block_t block = self->_tasks[key];
        if (block) {
            dispatch_block_cancel(block);
        }
        [self->_tasks removeObjectForKey:key];
    }];
}

- (void)cancellAllRequests {
    [self synchronize:^{
        [self->_tasks enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, dispatch_block_t  _Nonnull obj, BOOL * _Nonnull stop) {
            dispatch_block_t block = self->_tasks[key];
            if (block) {
                dispatch_block_cancel(block);
            }
            [self->_tasks removeObjectForKey:key];
        }];
    }];
}

- (BOOL)isActive:(NSString *)taskId {
    __block BOOL result = FALSE;
    [self synchronize:^{
        result = (self->_tasks.count > 0);
    }];
    return result;
}

#pragma mark - RTSPSegmentStreamer

- (void)createInterfaceFor:(BOOL)writable {
    if (writable) {
        if (!_writeInterface) {
            _writeInterface = [[ReadableWritableSegmentStreamer alloc] initWithStreamer:self];
        }
        [_writeInterface seekTo:0];
    } else {
        if (!_readInterface) {
            _readInterface = [[ReadableWritableSegmentStreamer alloc] initWithStreamer:self];
        }
        [_readInterface seekTo:0];
    }
}

- (id<ChangeableStreamer> _Nullable)getInterfaceFor:(BOOL)writable {
    if (writable) {
        return _writeInterface;
    } else {
        return _readInterface;
    }
}

- (BOOL)isReady {
    return ((!_writeInterface || [_writeInterface isFinished]) &&
            (!_readInterface || [_readInterface isFinished]));
}

- (void)dumpDataToFile {
    if ([self isReady]) {
        NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:self.sessionUrl.lastPathComponent];
        [_stream writeToFile:filePath atomically:TRUE];
    }
}

#pragma mark - RTSPSegmentStreamer ()

- (NSInteger)writeData:(const uint8_t *)buffer at:(NSUInteger)position length:(NSUInteger)length {
    if (position == self->_stream.length) {
        [self->_stream appendBytes:buffer length:length];
    } else {
        if (position + length > self->_stream.length) {
            NSUInteger diff = (position + length) - self->_stream.length;
            NSData *adj = [[NSMutableData alloc] initWithCapacity:diff];
            [self->_stream appendBytes:adj.bytes length:diff];
        }
        [self->_stream replaceBytesInRange:NSMakeRange(position, length) withBytes:buffer length:length];
//        [self->_stream replaceBytesInRange:NSMakeRange(position, 0) withBytes:buffer length:length];
    }
    return length;
}

- (NSData *)readDataAt:(NSUInteger)position length:(NSUInteger)length {
    NSInteger len = position + length;
    len = MIN(len, self->_stream.length) - position;
    if (position < self->_stream.length) {
        return [self readDataForRange:NSMakeRange(position, len)];
    }
    return NULL;
}

#pragma mark - Helpers

- (NSInteger)dataLength {
    return _stream.length;
}

- (NSData *)readDataForRange:(NSRange)range {
    UInt8 buffer[range.length];
    [_stream getBytes:&buffer range:range];
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

#pragma mark - Helpers (Sync)

- (void)synchronize:(synchronized_block)block {
    [_locker lock]; {
        block();
    }
    [_locker unlock];
}

@end
