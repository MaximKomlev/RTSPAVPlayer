//
//  definitions.h
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 12/11/18.
//  Copyright © 2018 Maxim Komlev. All rights reserved.
//

#ifndef definitions_h
#define definitions_h

#import <Foundation/Foundation.h>

typedef void (^synchronized_block)(void);

extern NSErrorDomain const RTSPAVPlayerErrorDomain;
extern NSTimeInterval const defaultLoadingTimeout;
extern NSInteger const fakeStreamSize;

@protocol StreamOptions <NSObject>

//#define TRACE_NETWORK 1
//#define TRACE_ERROR 1
//#define TRACE_STATUS 1
//#define TRACE_ALL 1
#define TRACE_TIME_STATUS 1

@end

#endif /* definitions_h */
