//
//  RTSPSegmenter.h
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 1/23/19.
//  Copyright © 2019 Maxim Komlev. All rights reserved.
//

#ifndef RTSPSegmenter_h
#define RTSPSegmenter_h

#import <Foundation/Foundation.h>

@class StreamOptions;

@interface RTSPSegmenter: NSObject

- (id)initWithUrl:(NSURL *_Nonnull)url;
- (id)initWithUrl:(NSURL *_Nonnull)url withOptions:(StreamOptions *)options;
- (void)start;
- (void)stop;

@property (atomic, readonly) BOOL isStopped;

@end

#endif /* RTSPSegmenter_h */
