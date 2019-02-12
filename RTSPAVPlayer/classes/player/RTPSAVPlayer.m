//
//  RTSPAVPlayer.m
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 12/14/18.
//  Copyright © 2018 Maxim Komlev. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RTSPAVPlayer.h"
#import "RTSPAVPlayerItem.h"
#import "RTSPSegmentController.h"
#import "definitions.h"
#import "RTSPAVAssetLoader.h"

@interface RTSPAVPlayer() <RTSPAVAssetDelegate, RTSPSegmentControllerDelegate, RTSPAVPlayerItemDelegate>
@end

@implementation RTSPAVPlayer {
    RTSPSegmentController *_RTSPSegmentController;
    NSArray *_assetKeys;
    NSMutableArray *_segments;
    id _timeObserverToken;
    Float64 _currentItemDuration;
}

static int AAPLPlayerKVOContext = 0;

- (instancetype _Nullable)initWithURL:(NSURL * _Nullable)url options:(StreamOptions * _Nullable)options withItemsAutoLoadedAssetKeys:(nullable NSArray<NSString *> *)itemAutoLoadedAssetKeys {
    if (self = [super init]) {
        [self addObservers];
        [self addPeriodicTimeObserver];

        _RTSPSegmentController = [[RTSPSegmentController alloc] initWithUrl:url withOptions:options];
        _RTSPSegmentController.delegate = self;
        _assetKeys = itemAutoLoadedAssetKeys;
        _segments = [NSMutableArray new];
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(playerStalledHandler:)
                                                     name: AVPlayerItemPlaybackStalledNotification
                                                   object: NULL];

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(errorHandler:)
                                                     name: AVPlayerItemNewErrorLogEntryNotification
                                                   object: NULL];

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(errorHandler:)
                                                     name: AVPlayerItemFailedToPlayToEndTimeNotification
                                                   object: NULL];
    }
    return self;
}

-(void)dealloc {
    [self removeObservers];
}

- (void)play {
    if (!self.isPlaying) {
        [_RTSPSegmentController start];
    }
}

- (void)pause {
    if (self.isPlaying) {
        [_RTSPSegmentController stop];
    }
}

- (BOOL)isPlaying {
    return _RTSPSegmentController.isActive;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != &AAPLPlayerKVOContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    RTSPAVPlayerItem *item = (RTSPAVPlayerItem *)self.currentItem;
    if ([keyPath isEqualToString:@"currentItem"]) {
        if (item) {
            item.isPlaying = TRUE;
        }
#if TRACE_STATUS || TRACE_ALL
        NSLog(@"RTSPAVPlayer:observeValueForKeyPath currentItem.url: %@", ((RTSPURLAsset *)item.asset).URL.absoluteString);
#endif
    } else if ([keyPath isEqualToString:@"status"]) {
        if (self.status == AVPlayerStatusFailed) {
#if TRACE_ERROR || TRACE_ALL
            NSLog(@"RTSPAVPlayer:observeValueForKeyPath status.Fail.url: %@, error: %@", ((RTSPURLAsset *)item.asset).URL.absoluteString, self.error);
#endif
        } else if (self.status == AVPlayerStatusReadyToPlay) {
#if TRACE_STATUS || TRACE_ALL
            NSLog(@"RTSPAVPlayer:observeValueForKeyPath status.ReadyToPlay.url: %@", ((RTSPURLAsset *)item.asset).URL.absoluteString);
#endif
        } else {
#if TRACE_STATUS || TRACE_ALL
            NSLog(@"RTSPAVPlayer:observeValueForKeyPath status.....url: %@", ((RTSPURLAsset *)item.asset).URL.absoluteString);
#endif
        }
    }
}

- (void)addObservers {
    [self addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:&AAPLPlayerKVOContext];
    [self addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:&AAPLPlayerKVOContext];
}

- (void)removeObservers {
    if ([self observationInfo]) {
        [self removeObserver:self forKeyPath:@"currentItem"];
        [self removeObserver:self forKeyPath:@"status"];
    }
}

- (void)addPeriodicTimeObserver {
    __weak typeof(self) weakSelf = self;
    _timeObserverToken = [self addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.21, NSEC_PER_SEC)
                                              queue:dispatch_get_main_queue()
                                         usingBlock:^(CMTime time) {
                                             __strong typeof(weakSelf) strongSelf = weakSelf;
                                             if (strongSelf) {
#if TRACE_TIME_STATUS || TRACE_ALL
                                                 NSString *currentItemURL = NULL;
                                                 RTSPAVPlayerItem *item = (RTSPAVPlayerItem *)self.currentItem;
                                                 if (item) {
                                                     currentItemURL = ((RTSPURLAsset *)item.asset).URL.absoluteString;
                                                 }
                                                 NSLog(@"RTSPAVPlayer:addPeriodicTimeObserverForInterval url: %@, time: %f, duration: %f", currentItemURL, CMTimeGetSeconds(time), self->_currentItemDuration);
#endif
                                             }
                                         }];
}

- (void)removePeriodicTimeObserver {
    
}

#pragma mark - RTSPAVPlayerItemDelegate

- (void)dataLoadedWithDuration:(Float64)duration {
    _currentItemDuration = duration;
}

#pragma mark - RTSPSegmentControllerDelegate

- (void)newSegmentReady:(RTSPSegmentStreamer *)segment {
    dispatch_async(dispatch_get_main_queue(), ^{
        RTSPURLAsset *asset = [[RTSPURLAsset alloc] initWithStreamer:(id)segment options:@{@"timeout": [NSNumber numberWithDouble:defaultLoadingTimeout]}];
        asset.delegate = self;
        RTSPAVPlayerItem *item = [RTSPAVPlayerItem playerItemWithAsset:asset automaticallyLoadedAssetKeys:self->_assetKeys];
        item.delegate = self;
        [self replaceCurrentItemWithPlayerItem:item];//????
        [super play];
    });
}

#pragma mark - RTSPAVAssetDelegate

- (void)headerLoadded:(NSDictionary *)header
                asset:(RTSPURLAsset *)asset {
#if TRACE_STATUS || TRACE_ALL
    NSLog(@"RTSPAVPlayer:headerLoadded, completely url: %@, header: %@", asset.URL.absoluteString, header);
#endif
}

- (void)dataLoaddedForRange:(NSRange)range
                      asset:(RTSPURLAsset *)asset {
#if TRACE_STATUS || TRACE_ALL
    NSLog(@"RTSPAVPlayer:newDataLoadded, range: %@, url: %@", [NSValue valueWithRange:range], asset.URL.absoluteString);
#endif
}

- (void)errorLoading:(NSError *)error
            forRange:(NSRange)range
               asset:(RTSPURLAsset *)asset {
#if TRACE_STATUS || TRACE_ALL
    NSLog(@"RTSPAVPlayer:errorLoading, error: %@, for range: %@", error.localizedDescription, [NSValue valueWithRange:range]);
#endif
}

#pragma mark - Helpers (Notification handlers)

- (void)playerStalledHandler:(NSNotification *)notification {
    RTSPAVPlayerItem *item = (RTSPAVPlayerItem *)self.currentItem;
    if (item) {
#if TRACE_ERROR || TRACE_ALL
        NSLog(@"RTSPAVPlayer:playerStalled, currentItem.url: %@", ((RTSPURLAsset *)item.asset).URL.absoluteString);
#endif
    }
}

- (void)errorHandler:(NSNotification *)notification {
    RTSPAVPlayerItem *item = (RTSPAVPlayerItem *)self.currentItem;
    if (item) {
#if TRACE_ERROR || TRACE_ALL
        NSLog(@"RTSPAVPlayer:errorHandler, currentItem.url: %@, error: %@", ((RTSPURLAsset *)item.asset).URL.absoluteString, item.errorLog);
#endif
    }
}

#pragma mark - Helpers (Sync)

- (void)appendItem:(RTSPAVPlayerItem *)item {
    [self->_segments addObject:item];
}

- (RTSPAVPlayerItem *)pullFirstItem {
    RTSPAVPlayerItem *item = NULL;
    if (self->_segments.count > 0) {
        item = self->_segments[0];
        [self->_segments removeObjectAtIndex:0];
    }
    return item;
}

@end
