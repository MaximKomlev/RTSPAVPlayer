//
//  ViewController.m
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 11/1/18.
//  Copyright © 2018 Maxim Komlev. All rights reserved.
//

#import "ViewController.h"

#import "definitions.h"
#import "RTSPAVPlayer.h"
#import "RTSPAVPlayerItem.h"

@interface ViewController () {
    NSArray *assetKeys;
}

@property (nonatomic, weak) AVPlayerLayer *playerLayer;
@property RTSPAVPlayer *player;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    UITapGestureRecognizer *singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    [self.view addGestureRecognizer:singleFingerTap];
    
    assetKeys = @[@"playable"];
    
    self.player =  [[RTSPAVPlayer alloc] initWithURL:[NSURL URLWithString:@"rtsp://184.72.239.149/vod/mp4:BigBuckBunny_175k.mov"]
                                             options:NULL
                        withItemsAutoLoadedAssetKeys:assetKeys];

    if (@available(iOS 10.0, *)) {
        self.player.automaticallyWaitsToMinimizeStalling = FALSE;
    }
    
    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    [self.view.layer addSublayer:playerLayer];
    self.playerLayer = playerLayer;
    [self.player play];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.playerLayer.frame = self.view.bounds;
}

#pragma mark - Events handlers

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    if (!self.player.isPlaying) {
        [self.player play];
    } else {
        [self.player pause];
    }
}

@end
