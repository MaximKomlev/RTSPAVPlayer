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

static int AAPLPlayerItemKVOContext = 0;

- (id)initWithURL:(NSURL *)URL {
    if (self = [super initWithURL:URL]) {
        [self addObservers];
    }
    return self;
}

- (id)initWithAsset:(AVAsset *)asset {
    if (self = [super initWithAsset:asset]) {
        [self addObservers];
    }
    return self;
}

- (id)initWithAsset:(AVAsset *)asset automaticallyLoadedAssetKeys:(NSArray<NSString *> *)automaticallyLoadedAssetKeys {
    if (self = [super initWithAsset:asset automaticallyLoadedAssetKeys:automaticallyLoadedAssetKeys]) {
        [self addObservers];
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

    if ([keyPath isEqualToString:@"status"]) {
        NSLog(@"RTSPAVPlayerItem:observeValueForKeyPath status.url: %@", ((RTSPURLAsset *)self.asset).URL.absoluteString);
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        NSLog(@"RTSPAVPlayerItem:observeValueForKeyPath playbackBufferEmpty.url: %@", ((RTSPURLAsset *)self.asset).URL.absoluteString);
    } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        NSLog(@"RTSPAVPlayerItem:observeValueForKeyPath playbackLikelyToKeepUp.url: %@", ((RTSPURLAsset *)self.asset).URL.absoluteString);
    } else if ([keyPath isEqualToString:@"AVPlayerItemDidPlayToEndTimeNotification"]) {
        NSLog(@"RTSPAVPlayerItem:observeValueForKeyPath AVPlayerItemDidPlayToEndTimeNotificationurl: %@", ((RTSPURLAsset *)self.asset).URL.absoluteString);
    }
}

- (void)addObservers {
    [self addObserver:self forKeyPath:@"status" options:0 context:&AAPLPlayerItemKVOContext];
    
    [self addObserver:self forKeyPath:@"AVPlayerItemDidPlayToEndTimeNotification" options:0 context:&AAPLPlayerItemKVOContext];
    [self addObserver:self forKeyPath:@"playbackBufferEmpty" options:0 context:&AAPLPlayerItemKVOContext];
    [self addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:0 context:&AAPLPlayerItemKVOContext];
}

- (void)removeObservers {
    if ([self observationInfo]) {
        [self removeObserver:self forKeyPath:@"status"];
        
        [self removeObserver:self forKeyPath:@"AVPlayerItemDidPlayToEndTimeNotification"];
        [self removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [self removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    }
}

@end
