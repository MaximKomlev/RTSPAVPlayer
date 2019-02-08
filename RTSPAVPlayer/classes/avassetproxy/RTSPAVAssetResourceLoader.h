
#import <AVFoundation/AVAssetResourceLoader.h>
#import "RTSPAVAssetDelegate.h"

#import "Streamer.h"

@protocol RTPAVAssetResourceLoaderDelegate <NSObject>

- (void)headerLoadded:(NSDictionary *)header;

- (void)dataChunkLoadded:(NSData *)data
                forRange:(NSRange)range;

- (void)dataLoaddedForRange:(NSRange)range;

- (void)errorLoading:(NSError *)error
            forRange:(NSRange)range;

@end

@interface RTSPAVAssetResourceLoader: NSObject <AVAssetResourceLoaderDelegate>

+ (NSString *)scheme;
- (instancetype)initWithStreamer:(id<Streamer> _Nonnull)streamer NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype) new NS_UNAVAILABLE;

@property (nonatomic, weak) NSObject<RTPAVAssetResourceLoaderDelegate> *delegate;

@property (nonatomic) NSTimeInterval networkTimeout;

@end
