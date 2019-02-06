//
//  SegmentsManager.h
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 1/23/19.
//  Copyright © 2019 Maxim Komlev. All rights reserved.
//

#ifndef SegmentsManager_h
#define SegmentsManager_h

#import <Foundation/Foundation.h>

@class RTSPSegmentStreamer;
@class ReadableWritableSegmentStreamer;

@protocol SegmentsManagerDelegate <NSObject>

- (void)segmentStarted:(RTSPSegmentStreamer *)segment;
- (void)segmentUpdated:(RTSPSegmentStreamer *)segment;
- (void)segmentFinished:(RTSPSegmentStreamer *)segment;
- (void)segmentRemoved:(RTSPSegmentStreamer *)segment;
- (void)segmentsRemoved;

@end

@interface SegmentsManager: NSObject <NSStreamDelegate>

+ (SegmentsManager *)instance;

- (void)startStreamForUrl:(NSString * _Nonnull)url writable:(BOOL)writable;
- (void)stopStreamForUrl:(NSString * _Nonnull)url writable:(BOOL)writable;
- (void)stopAllStreams;

- (NSInteger)writeStreamForUrl:(NSString * _Nonnull)url writable:(BOOL)writable data:(const uint8_t *)buffer length:(NSUInteger)len;
- (NSData * _Nullable)readStreamForUrl:(NSString * _Nonnull)url writable:(BOOL)writable length:(NSUInteger)len;
- (void)seekStreamForUrl:(NSString * _Nonnull)url writable:(BOOL)writable toPosition:(NSUInteger)position;

@property (nonatomic, weak) NSObject<SegmentsManagerDelegate> * _Nullable delegate;

@end

#endif /* SegmentsManager_h */
