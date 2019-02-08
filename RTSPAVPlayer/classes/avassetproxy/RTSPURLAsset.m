
#import "RTSPURLAsset.h"
#import "RTSPAVAssetResourceLoader.h"

#import "definitions.h"

#import "Streamer.h"

@interface RTSPURLAsset() <RTPAVAssetResourceLoaderDelegate> {
    RTSPAVAssetResourceLoader *_resourceLoaderDelegate;
}

@end

@implementation RTSPURLAsset

- (instancetype _Nullable)initWithStreamer:(id<Streamer> _Nonnull)streamer options:(NSDictionary<NSString *, id> * _Nullable)options {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:streamer.sessionUrl resolvingAgainstBaseURL:NO];
    components.scheme = [RTSPAVAssetResourceLoader scheme];
    
    if (self = [super initWithURL:[components URL] options:options]) {
        self->_resourceLoaderDelegate = [[RTSPAVAssetResourceLoader alloc] initWithStreamer:streamer];
        self->_resourceLoaderDelegate.networkTimeout = [((NSNumber *)options[@"timeout"]) doubleValue];
        self->_resourceLoaderDelegate.delegate = self;
        [self.resourceLoader setDelegate:_resourceLoaderDelegate queue:dispatch_get_main_queue()];
    }
    return self;
}

- (void)dealloc {
    [self shutdown];
}

- (void)shutdown {
}

#pragma mark - RTPAVAssetResourceLoaderDelegate

- (void)headerLoadded:(NSDictionary *)header {
    [_delegate headerLoadded:header asset:self];
}

- (void)dataChunkLoadded:(NSData *)data
                forRange:(NSRange)range {
}

- (void)dataLoaddedForRange:(NSRange)range {
    [_delegate dataLoaddedForRange:range asset:self];
}

- (void)errorLoading:(NSError *)error
            forRange:(NSRange)range {
    [_delegate errorLoading:error forRange:range asset:self];
}

@end
