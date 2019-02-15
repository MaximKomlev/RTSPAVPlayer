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
    NSArray *_assetKeys;
    AVPlayerLayer *_playerLayer;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    UITapGestureRecognizer *singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    [self.view addGestureRecognizer:singleFingerTap];
    
    _assetKeys = @[@"playable"];
    
    RTSPAVPlayer *player =  [[RTSPAVPlayer alloc] initWithURL:[NSURL URLWithString:@"rtsp://184.72.239.149/vod/mp4:BigBuckBunny_175k.mov"]
                                             options:NULL
                        withItemsAutoLoadedAssetKeys:_assetKeys];

    if (@available(iOS 10.0, *)) {
        player.automaticallyWaitsToMinimizeStalling = FALSE;
    }
    
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    [self.view.layer addSublayer:_playerLayer];
    [player play];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _playerLayer.frame = self.view.bounds;
}

#pragma mark - Events handlers

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    if (!((RTSPAVPlayer *)_playerLayer.player).isPlaying) {
        [_playerLayer.player play];
    } else {
        [_playerLayer.player pause];
    }
}

@end
