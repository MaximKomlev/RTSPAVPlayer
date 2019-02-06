//
//  RTSPSegmentController.h
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 12/5/18.
//  Copyright © 2018 Maxim Komlev. All rights reserved.
//

#ifndef RTSPSegmentController_h
#define RTSPSegmentController_h

#import <Foundation/Foundation.h>
#import <AVFoundation/AVAssetResourceLoader.h>

@class StreamOptions;
@class RTSPSegmentStreamer;

@protocol RTSPSegmentControllerDelegate <NSObject>

- (void)newSegmentReady:(RTSPSegmentStreamer *)segment;

@end

@interface RTSPSegmentController: NSObject

- (id)initWithUrl:(NSURL *)url withOptions:(StreamOptions * _Nullable)options;

- (void)start;
- (void)stop;

@property (atomic, readonly) BOOL isActive;
@property (nonatomic, weak) NSObject<RTSPSegmentControllerDelegate> * _Nullable delegate;

@end

#endif /* RTSPSegmentController_h */
