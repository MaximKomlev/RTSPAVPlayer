
#import <Foundation/Foundation.h>
#import <AVFoundation/AVAssetResourceLoader.h>
#import "RTSPURLAsset.h"

@protocol Streamer;

@protocol StreamerDelegate <NSObject>

- (void)responseHeader:(id<Streamer> _Nonnull)source withData:(NSDictionary * _Nullable)data forLoadingRequest:(AVAssetResourceLoadingRequest * _Nonnull)loadingRequest;
- (void)responseBody:(id<Streamer> _Nonnull)source withData:(NSData * _Nullable)data forLoadingRequest:(AVAssetResourceLoadingRequest * _Nonnull)loadingRequest;
- (void)responseEnd:(id<Streamer> _Nonnull)source forLoadingRequest:(AVAssetResourceLoadingRequest * _Nonnull)loadingRequest withError:(NSError * _Nullable)error;

@end

@protocol Streamer <NSObject>

- (instancetype _Nonnull)initWithUrl:(NSURL *_Nonnull)url;

- (void)performRequest:(NSDictionary<NSString *, NSObject *> * _Nullable)params forAVLoadingRequest:(AVAssetResourceLoadingRequest *_Nonnull)loadingRequest;

- (BOOL)isActive;

@property (strong, nonatomic, readonly) NSURL * _Nonnull sessionUrl;
@property (nonatomic, weak) NSObject<StreamerDelegate> * _Nullable delegate;

@end
