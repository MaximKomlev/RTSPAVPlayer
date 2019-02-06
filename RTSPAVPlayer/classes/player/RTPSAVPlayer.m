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

@interface RTSPAVPlayer() <RTSPAVAssetDelegate, RTSPSegmentControllerDelegate>
@end

@implementation RTSPAVPlayer {
    RTSPSegmentController *_RTSPSegmentController;
    NSArray *_assetKeys;
}

static int AAPLPlayerViewControllerKVOContext = 0;

- (instancetype _Nullable)initWithURL:(NSURL * _Nullable)url options:(StreamOptions * _Nullable)options withItemsAutoLoadedAssetKeys:(nullable NSArray<NSString *> *)itemAutoLoadedAssetKeys {
    if (self = [super init]) {
        [self addObservers];

        _RTSPSegmentController = [[RTSPSegmentController alloc] initWithUrl:url withOptions:options];
        _RTSPSegmentController.delegate = self;
        _assetKeys = itemAutoLoadedAssetKeys;
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

- (void)insertItem:(AVPlayerItem *)item afterItem:(AVPlayerItem *)afterItem {
    [super insertItem:item afterItem:afterItem];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != &AAPLPlayerViewControllerKVOContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    if ([keyPath isEqualToString:@"currentItem"]) {
//        [self seekToTime:kCMTimeZero];
//        [self seekToTime:kCMTimeZero toleranceBefore:kCMTimePositiveInfinity toleranceAfter:kCMTimeZero];
        [self seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:self.currentTime];

        [self.items enumerateObjectsUsingBlock:^(AVPlayerItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            RTSPAVPlayerItem *item = (RTSPAVPlayerItem *)obj;
            if (item) {
                item.isPlaying = FALSE;
            }
        }];
        RTSPAVPlayerItem *item = (RTSPAVPlayerItem *)self.currentItem;
        if (item) {
            item.isPlaying = TRUE;
        }
        [super play];
    }
}

- (void)addObservers {
    [self addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:&AAPLPlayerViewControllerKVOContext];
}

- (void)removeObservers {
    if ([self observationInfo]) {
        [self removeObserver:self forKeyPath:@"currentItem"];
    }
}

#pragma mark - RTSPSegmentControllerDelegate

- (void)newSegmentReady:(RTSPSegmentStreamer *)segment {
    RTSPURLAsset *asset = [[RTSPURLAsset alloc] initWithStreamer:(id)segment options:@{@"timeout": [NSNumber numberWithDouble:defaultLoadingTimeout]}];
    asset.delegate = self;
    [self insertItem:[RTSPAVPlayerItem playerItemWithAsset:asset automaticallyLoadedAssetKeys:self->_assetKeys] afterItem:NULL];
}

#pragma mark - RTSPAVAssetDelegate

- (void)headerLoadded:(NSDictionary *)header
                asset:(RTSPURLAsset *)asset {
    //NSLog(@"ViewController:headerLoadded, completely url: %@", asset.URL.absoluteString);
}

- (void)dataLoaddedForRange:(NSRange)range
                      asset:(RTSPURLAsset *)asset {
    //NSLog(@"ViewController:newDataLoadded, range: %@, url: %@", [NSValue valueWithRange:range], asset.URL.absoluteString);
}

- (void)errorLoading:(NSError *)error
            forRange:(NSRange)range
               asset:(RTSPURLAsset *)asset {
    //NSLog(@"ViewController:errorLoading, error: %@, for range: %@", error.localizedDescription, [NSValue valueWithRange:range]);
}

@end
