//
//  RTSPAVPlayer.h
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 12/14/18.
//  Copyright © 2018 Maxim Komlev. All rights reserved.
//

#ifndef RTSPAVPlayer_h
#define RTSPAVPlayer_h

#import <AVFoundation/AVFoundation.h>

@class StreamOptions;

@interface RTSPAVPlayer: AVPlayer

- (instancetype _Nullable)initWithURL:(NSURL * _Nullable)url options:(StreamOptions * _Nullable)options withItemsAutoLoadedAssetKeys:(nullable NSArray<NSString *> *)itemAutoLoadedAssetKeys;

@property (atomic, readonly) BOOL isPlaying;

@end

#endif /* RTSPAVPlayer_h */
