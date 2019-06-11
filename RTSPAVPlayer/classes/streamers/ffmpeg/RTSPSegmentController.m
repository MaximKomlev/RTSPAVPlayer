//
//  RTSPSegmentController.m
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 12/5/18.
//  Copyright © 2018 Maxim Komlev. All rights reserved.
//
#import <libavformat/avformat.h>
#import <libavutil/timestamp.h>

#import "RTSPSegmentController.h"
#import "RTSPSegmenter.h"
#import "SegmentsManager.h"
#import "definitions.h"

@interface RTSPSegmentController () <SegmentsManagerDelegate>

@end

@implementation RTSPSegmentController  {
    RTSPSegmenter *_RTSPSegmenter;
}

- (id)initWithUrl:(NSURL *)url withOptions:(NSDictionary * _Nullable)options {
    if (self = [self init]) {
        _RTSPSegmenter = [[RTSPSegmenter alloc] initWithUrl:url withOptions:options];
        [SegmentsManager instance].delegate = self;
    }
    return self;
}

#pragma mark - Request public interface

- (void)start {
    [self->_RTSPSegmenter start];
}

- (void)stop {
    [self->_RTSPSegmenter stop];
}

- (BOOL)isActive {
    return !self->_RTSPSegmenter.isStopped;
}

#pragma mark - SegmentsManagerDelegate

- (void)segmentStarted:(RTSPSegmentStreamer *)segment {
}

- (void)segmentUpdated:(RTSPSegmentStreamer *)segment {
}

- (void)segmentFinished:(RTSPSegmentStreamer *)segment {
    [_delegate newSegmentReady:segment];
}

- (void)segmentsRemoved {
}

- (void)segmentRemoved:(RTSPSegmentStreamer *)segment {
}

@end
