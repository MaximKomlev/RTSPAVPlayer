
#import <MobileCoreServices/UTType.h>
#import <SystemConfiguration/SCNetworkReachability.h>

#import "RTSPAVAssetResourceLoader.h"
#import "Streamer.h"
#import "definitions.h"

@interface LoadingError : NSObject

+ (instancetype)createWithError:(NSError *)error;

@property (nonatomic, readonly) NSError *error;
@property (nonatomic, readonly) NSDate *date;

@end

@implementation LoadingError

+ (instancetype)createWithError:(NSError *)error {
    return [[LoadingError alloc] initWithError:error];
}

- (instancetype)initWithError:(NSError *)error {
    if (self = [super init]) {
        _error = error;
        _date = [NSDate date];
    }
    
    return self;
}

@end


@interface RTSPAVAssetResourceLoader () <StreamerDelegate>

@property (nonatomic, readonly) id<Streamer> streamer;

@property (nonatomic) LoadingError *loadingError;

@end

@implementation RTSPAVAssetResourceLoader

#pragma mark - Public

- (instancetype)initWithStreamer:(id<Streamer> _Nonnull)streamer {
    if (self = [super init]) {
        _streamer = streamer;
        _streamer.delegate = self;
        _networkTimeout = defaultLoadingTimeout;
    }

    return self;
}

- (void)dealloc {
}

- (instancetype)init {
    @throw [NSString stringWithFormat:@"Init unavailable. Use %@ instead.", NSStringFromSelector(@selector(initWithURL:))];
}

+ (instancetype) new {
    @throw [NSString stringWithFormat:@"New unavailable. Use alloc %@ instead.", NSStringFromSelector(@selector(initWithURL:))];
}

+ (NSString *)scheme {
    return NSStringFromClass(self);
}

#pragma mark - Resource loader delegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    if (![loadingRequest.request.URL.scheme isEqualToString:[[self class] scheme]]) {
        return NO;
    }
    
    NSMutableDictionary *params = [NSMutableDictionary new];
    if (loadingRequest.contentInformationRequest) {
        params[@"HTTPMethod"] = @"HEAD";
    } else if (loadingRequest.dataRequest.requestsAllDataToEndOfResource) {
        NSInteger requestedOffset = loadingRequest.dataRequest.requestedOffset;
        params[@"allHTTPHeaderFields"] = @{ @"Range" : [NSString stringWithFormat:@"bytes=%ld-", (long)requestedOffset] };
    } else if (loadingRequest.dataRequest) {
        NSInteger requestedOffset = loadingRequest.dataRequest.requestedOffset;
        NSInteger requestedLength = loadingRequest.dataRequest.requestedLength;
        params[@"allHTTPHeaderFields"] = @{ @"Range" : [NSString stringWithFormat:@"bytes=%ld-%ld", (long)requestedOffset, requestedOffset + requestedLength - 1] };
    } else {
        return NO;
    }
    
    [self.streamer performRequest:params forAVLoadingRequest:loadingRequest];

    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
}

#pragma mark - StreamerDelegate

- (void)responseHeader:(id<Streamer>)source withData:(NSDictionary *)data forLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (loadingRequest.contentInformationRequest) {
            [self processContentInformation:loadingRequest.contentInformationRequest fromHeader:data];
            [loadingRequest finishLoading];
        }
    });
}

- (void)responseBody:(id<Streamer>)source withData:(NSData *)data forLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    dispatch_async(dispatch_get_main_queue(), ^{
        [loadingRequest.dataRequest respondWithData:data];
        NSInteger requestedOffset = loadingRequest.dataRequest.requestedOffset;
        NSInteger requestedLength = loadingRequest.dataRequest.requestedLength;
        
        NSRange range = NSMakeRange(requestedOffset, requestedLength);
        if ([self.delegate respondsToSelector:@selector(dataChunkLoadded:forRange:)]) {
            [self.delegate dataChunkLoadded:data forRange:range];
        }
        if ([self.delegate respondsToSelector:@selector(dataLoaddedForRange:)]) {
            [self.delegate dataLoaddedForRange:range];
        }
        [loadingRequest finishLoading];
    });
}

- (void)responseEnd:(id<Streamer>)source forLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest withError:(NSError * _Nullable)error {
}

#pragma mark - Downloaded data processing

- (void)processContentInformation:(AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest fromHeader:(NSDictionary<NSString *, NSObject *> * _Nullable)header {
    NSString *mimeType = @"video/mp4";
    if (header) {
        mimeType = (NSString *)header[@"MIMEType"];
    }

    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    contentInformationRequest.contentType = CFBridgingRelease(contentType);

    contentInformationRequest.byteRangeAccessSupported = TRUE;
    NSNumber *contentLength = (NSNumber *)header[@"ContentLength"];
    contentInformationRequest.contentLength = [contentLength longLongValue];
    
    if ([self.delegate respondsToSelector:@selector(headerLoadded:)]) {
        [self.delegate headerLoadded:header];
    }
}

@end
