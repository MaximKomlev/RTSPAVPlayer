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

- (BOOL)isPlaying {
    return _isPlaying;
}

- (void)setIsPlaying:(BOOL)isPlaying {
    _isPlaying = isPlaying;
}

@end
