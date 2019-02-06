
#import <AVFoundation/AVFoundation.h>
#import "RTSPAVAssetDelegate.h"

@protocol Streamer;

@interface RTSPURLAsset : AVURLAsset

- (instancetype _Nullable)initWithStreamer:(id<Streamer> _Nonnull)streamer options:(NSDictionary<NSString *, id> * _Nullable)options;

@property (nonatomic, weak) NSObject <RTSPAVAssetDelegate> * _Nullable delegate;

- (void)shutdown;

@end
