
#import "RTSPSegmentStreamer.h"
#import "definitions.h"
#import "stringutils.h"

@interface ReadableWritableSegmentStreamer () {
    NSInteger _offset;
    BOOL _isFinished;
}

- (BOOL)isFinished;

@end

@interface RTSPSegmentStreamer () <NSStreamDelegate> {
    NSMutableData *_stream;
    dispatch_queue_t _queue;

    ReadableWritableSegmentStreamer *_writeInterface;
    ReadableWritableSegmentStreamer *_readInterface;
}

- (id)init;

- (NSInteger)writeData:(const uint8_t *)buffer at:(NSUInteger)position length:(NSUInteger)length;
- (NSData *)readDataAt:(NSUInteger)position length:(NSUInteger)length;

- (void)synchronizedAccess:(synchronized_block)block;

@end

@implementation ReadableWritableSegmentStreamer

- (instancetype)init {
    if (self = [super init]) {
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
    [_stream synchronizedAccess: ^{
        [self->_stream writeData:buffer at:self->_offset length:length];
        self->_offset += length;
    }];
    return length;
 }

- (NSData *)readData:(NSUInteger)length {
    __block NSData *data = NULL;
    [_stream synchronizedAccess: ^{
        data = [self->_stream readDataAt:self->_offset length:length];
        self->_offset += data.length;
    }];
    return data;
}

- (void)seekTo:(NSUInteger)position {
    [_stream synchronizedAccess: ^{
        self->_offset = position;
    }];
}

- (void)finish {
    [_stream synchronizedAccess: ^{
        self->_isFinished = TRUE;
    }];
}

- (BOOL)isFinished {
    __block BOOL result = FALSE;
    [_stream synchronizedAccess: ^{
        result = self->_isFinished;
    }];
    return result;
}

@end

@implementation RTSPSegmentStreamer

@synthesize delegate;
@synthesize sessionUrl = _sessionUrl;

static NSString *_identificatorName = @"streamId";

- (instancetype)init {
    if (self = [super init]) {
        _queue = dispatch_queue_create("_RTSPSegmentStreamer_", DISPATCH_QUEUE_SERIAL);
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
    if (!loadingRequest.isCancelled && [self isReady]) {
        if (loadingRequest.contentInformationRequest) {
            if ([self.delegate respondsToSelector:@selector(responseHeader:withData:forLoadingRequest:)]) {
                NSInteger length = [self dataLength];
                NSDictionary<NSString *, NSObject *> *header = @{@"MIMEType"        : @"video/mp4",
                                                                 @"ContentLength"   : [NSNumber numberWithLongLong:length]};
                [self.delegate responseHeader:self withData:header forLoadingRequest:loadingRequest];
            }
        } else if (loadingRequest.dataRequest.requestsAllDataToEndOfResource) {
            if ([self.delegate respondsToSelector:@selector(responseBody:withData:forLoadingRequest:)]) {
                NSInteger requestedOffset = loadingRequest.dataRequest.requestedOffset;
                NSInteger requestedLength = [self dataLength] - loadingRequest.dataRequest.requestedOffset;
                [self.delegate responseBody:self withData:[self readDataForRange:NSMakeRange(requestedOffset, requestedLength)] forLoadingRequest:loadingRequest];
            }
            if ([self.delegate respondsToSelector:@selector(responseEnd:forLoadingRequest:withError:)]) {
                [self.delegate responseEnd:self forLoadingRequest:loadingRequest withError:NULL];
            }
        } else if (loadingRequest.dataRequest) {
            NSInteger requestedOffset = loadingRequest.dataRequest.requestedOffset;
            NSInteger requestedLength = loadingRequest.dataRequest.requestedLength;
            if ([self.delegate respondsToSelector:@selector(responseBody:withData:forLoadingRequest:)]) {
                [self.delegate responseBody:self withData:[self readDataForRange:NSMakeRange(requestedOffset, requestedLength)] forLoadingRequest:loadingRequest];
            }
            if ([self.delegate respondsToSelector:@selector(responseEnd:forLoadingRequest:withError:)]) {
                [self.delegate responseEnd:self forLoadingRequest:loadingRequest withError:NULL];
            }
        }
    }
}

- (BOOL)isActive:(NSString *)taskId {
    return TRUE;
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

- (void)synchronizedAccess:(synchronized_block)block {
    dispatch_sync(_queue, ^{
        block();
    });
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

@end
