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
#import "RTSPAVPlayer-Swift.h"

@interface ViewController () {
    NSArray *_assetKeys;
    AVPlayerLayer *_playerLayer;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];

    self.title = @"Objective C Sample";
    
    UITapGestureRecognizer *singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    [self.view addGestureRecognizer:singleFingerTap];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    _playerLayer.frame = self.view.bounds;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    _assetKeys = @[@"playable"];
    
    //https://www.wowza.com/html/mobile.html
    RTSPAVPlayer *player =  [[RTSPAVPlayer alloc] initWithURL:[NSURL URLWithString:@"rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov"]
                                                      options:NULL
                                 withItemsAutoLoadedAssetKeys:_assetKeys];
    
    if (@available(iOS 10.0, *)) {
        player.automaticallyWaitsToMinimizeStalling = FALSE;
    }
    
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    [self.view.layer addSublayer:_playerLayer];
    [player play];
    
    UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithTitle:@"Swift Sample" style:UIBarButtonItemStylePlain target:self action:@selector(buttonNextTouched:)];
    self.navigationItem.rightBarButtonItem = rightButton;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [_playerLayer.player pause];
}

#pragma mark - Events handlers

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    if (!((RTSPAVPlayer *)_playerLayer.player).isPlaying) {
        [_playerLayer.player play];
    } else {
        [_playerLayer.player pause];
    }
}

- (void)buttonNextTouched:(id)sender {
    SwiftViewController *vc = [[SwiftViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
