//
//  SwiftViewController.swift
//  RTSPAVPlayer
//
//  Created by Maxim Komlev on 6/10/19.
//  Copyright © 2019 Maxim Komlev. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation
import ObjectiveC

class SwiftViewController: UIViewController {
    
    private var playerLayer: AVPlayerLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view = UIView(frame: UIScreen.main.bounds)
        
        title = "Swift Sample"
        
        let singleFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        view.addGestureRecognizer(singleFingerTap)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let url = URL(string: "rtsp://184.72.239.149/vod/mp4:BigBuckBunny_175k.mov") else {
            return
        }
        
        let player = RTSPAVPlayer(url: url, options: nil, withItemsAutoLoadedAssetKeys: ["playable"])

        if #available(iOS 10.0, *) {
            player?.automaticallyWaitsToMinimizeStalling = false
        }

        playerLayer = AVPlayerLayer(player: player)
        self.view.layer.addSublayer(playerLayer!)
        player?.play()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        playerLayer?.player?.pause()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        playerLayer?.frame = self.view.bounds
    }
    
    @objc func handleSingleTap(recognizer: UITapGestureRecognizer) {
        if let player = playerLayer?.player as? RTSPAVPlayer {
            if player.isPlaying {
                player.pause()
            } else {
                player.play()
            }
        }
    }
}
