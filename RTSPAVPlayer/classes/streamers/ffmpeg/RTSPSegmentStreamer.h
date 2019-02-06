
#ifndef HTTPStreamer_h
#define HTTPStreamer_h

#import <Foundation/Foundation.h>
#import <AVFoundation/AVAssetResourceLoader.h>

#import "Streamer.h"

@class RTSPSegmentStreamer;

@protocol ChangeableStreamer <NSObject>

- (NSInteger)writeData:(const uint8_t *)buffer length:(NSUInteger)len;
- (NSData * _Nullable)readData:(NSUInteger)len;
- (void)seekTo:(NSUInteger)position;
- (void)finish;

@end

@interface ReadableWritableSegmentStreamer: NSObject <ChangeableStreamer>

- (instancetype _Nonnull)initWithStreamer:(RTSPSegmentStreamer *_Nonnull)stream;
@property (nonatomic, readonly, weak) RTSPSegmentStreamer * _Nullable stream;

@end

@interface WritableSegmentStreamer: ReadableWritableSegmentStreamer

@end

@interface ReadableSegmentStreamer: ReadableWritableSegmentStreamer

@end

@interface RTSPSegmentStreamer: NSObject <Streamer>

- (instancetype _Nonnull)initWithUrl:(NSURL *_Nonnull)url;

- (void)createInterfaceFor:(BOOL)writable;
- (id<ChangeableStreamer> _Nullable)getInterfaceFor:(BOOL)writable;

- (BOOL)isReady;

- (void)dumpDataToFile;

@end

#endif /* HTTPStreamer_h */
