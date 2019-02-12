//
//  RTSPAVPlayerItem.m
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 12/14/18.
//  Copyright © 2018 Maxim Komlev. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RTSPURLAsset.h"
#import "RTSPAVPlayerItem.h"

@implementation RTSPAVPlayerItem

@synthesize isPlaying = _isPlaying;
@synthesize isLoaded = _isLoaded;

static int AAPLPlayerItemKVOContext = 0;

- (id)initWithURL:(NSURL *)URL {
    if (self = [super initWithURL:URL]) {
        [self addObservers];
        _isLoaded = FALSE;
    }
    return self;
}

- (id)initWithAsset:(AVAsset *)asset {
    if (self = [super initWithAsset:asset]) {
        [self addObservers];
        _isLoaded = FALSE;
    }
    return self;
}

- (id)initWithAsset:(AVAsset *)asset automaticallyLoadedAssetKeys:(NSArray<NSString *> *)automaticallyLoadedAssetKeys {
    if (self = [super initWithAsset:asset automaticallyLoadedAssetKeys:automaticallyLoadedAssetKeys]) {
        [self addObservers];
        _isLoaded = FALSE;
    }
    return self;
}

-(void)dealloc {
}

- (BOOL)isPlaying {
    return _isPlaying;
}

- (void)setIsPlaying:(BOOL)isPlaying {
    _isPlaying = isPlaying;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (context != &AAPLPlayerItemKVOContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

//    NSLog(@"RTSPAVPlayerItem:observeValueForKeyPath keyPath[%@].fail.url: %@, change: %@", keyPath, ((RTSPURLAsset *)self.asset).URL.absoluteString, change);
    
    if ([keyPath isEqualToString:@"status"]) {
        if (self.status == AVPlayerItemStatusFailed) {
#if TRACE_ERROR || TRACE_ALL
            NSLog(@"RTSPAVPlayerItem:observeValueForKeyPath status.fail.url: %@, error: %@", ((RTSPURLAsset *)self.asset).URL.absoluteString, self.error);
#endif
        }
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
    } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        _isLoaded = TRUE;
        if ([self.delegate respondsToSelector:@selector(dataLoadedWithDuration:)]) {
            Float64 duration = CMTimeGetSeconds(self.asset.duration);
            [self.delegate dataLoadedWithDuration:duration];
        }
    } else if ([keyPath isEqualToString:@"errorLog"]) {
#if TRACE_ERROR || TRACE_ALL
        NSLog(@"RTSPAVPlayerItem:observeValueForKeyPath status.Fail.url: %@, error: %@", ((RTSPURLAsset *)self.asset).URL.absoluteString, self.error);
#endif
    }
}

- (void)addObservers {
    [self addObserver:self forKeyPath:@"status" options:0 context:&AAPLPlayerItemKVOContext];
    [self addObserver:self forKeyPath:@"errorLog" options:0 context:&AAPLPlayerItemKVOContext];

    [self addObserver:self forKeyPath:@"AVPlayerItemDidPlayToEndTimeNotification" options:0 context:&AAPLPlayerItemKVOContext];
    [self addObserver:self forKeyPath:@"playbackBufferEmpty" options:0 context:&AAPLPlayerItemKVOContext];
    [self addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:0 context:&AAPLPlayerItemKVOContext];
}

- (void)removeObservers {
    if ([self observationInfo]) {
        [self removeObserver:self forKeyPath:@"status"];
        [self removeObserver:self forKeyPath:@"errorLog"];

        [self removeObserver:self forKeyPath:@"AVPlayerItemDidPlayToEndTimeNotification"];
        [self removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [self removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    }
}

@end
