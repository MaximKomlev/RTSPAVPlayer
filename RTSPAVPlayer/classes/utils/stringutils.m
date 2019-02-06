//
//  stringutils.m
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 11/30/18.
//  Copyright © 2018 Maxim Komlev. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "stringutils.h"

const NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
NSString* randomString(int len) {
    NSMutableString *rString = [NSMutableString stringWithCapacity: len];
    for (int i=0; i<len; i++) {
        [rString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform([letters length])]];
    }
    return rString;
}
