
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
    
    // check reachability only if there was network error before
    if (self.loadingError) {
        BOOL nowReachable = [self isNetworkReachable];
        if (nowReachable) {
            self.loadingError = nil;
        } else if ([[NSDate date] timeIntervalSinceDate:self.loadingError.date] > self.networkTimeout){
            NSInteger requestedOffset = loadingRequest.dataRequest.requestedOffset;
            NSInteger requestedLength = loadingRequest.dataRequest.requestedLength;
            NSRange range = NSMakeRange(requestedOffset, requestedLength);

            if ([self.delegate respondsToSelector:@selector(errorLoading:forRange:)]) {
                [self.delegate errorLoading:self.loadingError.error forRange:range];
            }
            return NO;
        } else {
            [loadingRequest finishLoadingWithError:self.loadingError.error];
            return YES;
        }
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
//    dispatch_async(dispatch_get_main_queue(), ^{
        if (loadingRequest.contentInformationRequest) {
            [self processContentInformation:loadingRequest.contentInformationRequest fromHeader:data];
            [loadingRequest finishLoading];
        }
//    });
}

- (void)responseBody:(id<Streamer>)source withData:(NSData *)data forLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
//    dispatch_async(dispatch_get_main_queue(), ^{
        [loadingRequest.dataRequest respondWithData:data];
        if ([self.delegate respondsToSelector:@selector(dataChunkLoadded:forRange:)]) {
            NSInteger requestedOffset = loadingRequest.dataRequest.requestedOffset;
            NSInteger requestedLength = loadingRequest.dataRequest.requestedLength;
            
            NSRange range = NSMakeRange(requestedOffset, requestedLength);

            [self.delegate dataChunkLoadded:data forRange:range];
        }
//    });
}

- (void)responseEnd:(id<Streamer>)source forLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest withError:(NSError * _Nullable)error {
//    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger requestedOffset = loadingRequest.dataRequest.requestedOffset;
        NSInteger requestedLength = loadingRequest.dataRequest.requestedLength;
        
        NSRange range = NSMakeRange(requestedOffset, requestedLength);

        if (error) {
            [loadingRequest finishLoadingWithError:error];
            if ([self.delegate respondsToSelector:@selector(errorLoading:forRange:)]) {
                [self.delegate errorLoading:error forRange:range];
            }
        } else {
            [loadingRequest finishLoading];
            if ([self.delegate respondsToSelector:@selector(dataLoaddedForRange:)]) {
                [self.delegate dataLoaddedForRange:range];
            }
        }
        
        BOOL isCancelledError = [error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled;
        BOOL isNetworkError = [error.domain isEqualToString:NSURLErrorDomain] && error.code != NSURLErrorCancelled;
        
        if (error && !isCancelledError && !isNetworkError) {
            if ([self.delegate respondsToSelector:@selector(errorLoading:forRange:)]) {
                [self.delegate errorLoading:error forRange:range];
            }
        }
        
        if (error && isNetworkError) {
            self.loadingError = [LoadingError createWithError:error];
        }
//    });
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

#pragma mark - Helpers

- (BOOL)isNetworkReachable {
    const char *host_name = [@"google.com" cStringUsingEncoding:NSASCIIStringEncoding];
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, host_name);
    SCNetworkReachabilityFlags flags;
    BOOL success = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    return success && (flags & kSCNetworkFlagsReachable) && !(flags & kSCNetworkFlagsConnectionRequired);
}

@end
