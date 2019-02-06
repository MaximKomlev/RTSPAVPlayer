//
//  RTSPAVAssetResourceLoader.h
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 11/2/18.
//  Copyright © 2018 Maxim Komlev. All rights reserved.
//

#ifndef RTPAVAssetDelegate_h
#define RTPAVAssetDelegate_h

#import <AVFoundation/AVFoundation.h>
@class RTSPURLAsset;
@class RTSPAVAssetResourceLoader;

@protocol RTSPAVAssetDelegate <NSObject>

@optional
- (void)dataLoaddedForRange:(NSRange)range
                      asset:(RTSPURLAsset *)asset;

- (void)headerLoadded:(NSDictionary *)header
                asset:(RTSPURLAsset *)asset;

- (void)errorLoading:(NSError *)error
            forRange:(NSRange)range
               asset:(RTSPURLAsset *)asset;

@end


#endif /* RTPAVAssetDelegate_h */
