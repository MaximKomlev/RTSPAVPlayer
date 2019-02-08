//
//  RTSPAVPlayerItem.h
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 12/14/18.
//  Copyright © 2018 Maxim Komlev. All rights reserved.
//

#ifndef RTSPAVPlayerItem_h
#define RTSPAVPlayerItem_h

#import <AVFoundation/AVFoundation.h>

@protocol RTSPAVPlayerItemDelegate <NSObject>

- (void)dataLoaded;

@end

@interface RTSPAVPlayerItem : AVPlayerItem

@property BOOL isPlaying;
@property (readonly) BOOL isLoaded;

@property (nonatomic, weak) id<RTSPAVPlayerItemDelegate> _Nullable delegate;

@end


#endif /* RTSPAVPlayerItem_h */
