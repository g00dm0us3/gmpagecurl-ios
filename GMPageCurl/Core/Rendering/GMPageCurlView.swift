//
//  GMPageCurlView.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 2/4/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import UIKit
import MetalKit

enum PageTurnProgress: Float {
    case zero = 0
    case quarter = 0.5
    case halfWay = 1
    case threeQuarters = 1.5
}

protocol GMPageCurlDatasource: class {
    func makePageView() -> UIView
    func updatePageView(_ view: UIView, pageIndex: UInt32)
}

final class GMPageCurlView: UIView {
    
    /// Threshold, after which the flip animation kicks in. The greater value means that user has to drag finger longer, before page flips automatically.
    var flipAnimationThreshold = PageTurnProgress.zero
    
    weak var dataSource: GMPageCurlDatasource?
    
    private(set) var currentPageIndex = UInt32(0)
    
    private let metalPageCurlView = MetalPageCurlView()
    
    private var onScreenPage: UIView?
    private var offScreenPage: UIView?
    
    init() {
        super.init(frame: .zero)
        
        addSubview(metalPageCurlView)
        metalPageCurlView.frame = bounds
        metalPageCurlView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        metalPageCurlView.isHidden = true
        metalPageCurlView.delegate = self
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panHandler(gesture:)))
        addGestureRecognizer(panGesture)
    }
    
    
    func loadPages() {
        onScreenPage?.removeFromSuperview()
        onScreenPage = nil
        guard let ds = dataSource else { return }
       
        onScreenPage = ds.makePageView()
        
    }
    
    @objc
    private func panHandler(gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        guard PanGestureTransformer.shouldTransform(translation) else { return }
        
        if gesture.state == .began {
            // intentially not using topSubview's frame here, since if it doesn't match the size
            // of curl view, the behavior is pretty much undefined (book has non-uniform page sizes)
            let imageRenderer = UIGraphicsImageRenderer(size: frame.size)

            let image = imageRenderer.image { (ctx) in
                self.layer.render(in: ctx.cgContext)
            }
            
            isUserInteractionEnabled = false
            
            metalPageCurlView.beginFlip(with: image.cgImage!, flipDirection: MetalPageCurlView.FlipDirection(translation))
        }
        
        if gesture.state == .changed {
            metalPageCurlView.updateFlip(translation: translation)
        }
        
        if gesture.state == .ended { /// - todo: only after flip back / forward animtion ends
            metalPageCurlView.endFlip(flipAnimationThreshold: flipAnimationThreshold)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension GMPageCurlView: MetalCurlViewDelegate {
    func didStart(flipAnimation inView: MetalPageCurlView) {
        return
    }
    
    func didFinish(flipAnimation inView: MetalPageCurlView) {
        isUserInteractionEnabled = true
        print("User interction enabled")
    }
}
