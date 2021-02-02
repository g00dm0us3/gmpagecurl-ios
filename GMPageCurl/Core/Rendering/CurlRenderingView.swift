//
//  CurlRenderingView.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 7/15/20.
//  Copyright © 2020 Homer. All rights reserved.
//

import UIKit

/// - TODO: implement sampleCount (MSAA)
final class CurlRenderingView: UIView {
    private var renderer: CurlRenderer
    override class var layerClass: AnyClass { return CAMetalLayer.self }

    private var isRunningPlayBack = false
    private var needsRender: Bool {
        didSet {
            caDisplayLink?.isPaused = !needsRender
        }
    }
    
    var curlParams = CurlParams(phi: 0, delta: 0) {
        didSet {
            needsRender = true
        }
    }
    
    private var caDisplayLink: CADisplayLink!
    private let transformer = PanGestureTransformer(maxPhi: CGFloat.pi/3, turnPageDistanceThreshold: 1.5)
    private let playBackStep = Float(0.09)
    
    override init(frame: CGRect) {
        self.renderer = CurlRenderer()
        self.needsRender = true
        super.init(frame: frame)
        guard let mtlLayer = layer as? CAMetalLayer else { fatalError("This should be metal layer!") }

        mtlLayer.device = DeviceWrapper.device
        mtlLayer.pixelFormat = MTLPixelFormat.bgra8Unorm
        isOpaque = false
        mtlLayer.isOpaque = false
        self.caDisplayLink = CADisplayLink(target: self, selector: #selector(displayLink))
        self.caDisplayLink.add(to: .current, forMode: .default)
        
        let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(move))
        gestureRecognizer.minimumNumberOfTouches = 1
        gestureRecognizer.maximumNumberOfTouches = 1
        gestureRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(gestureRecognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    // MARK: Public Interface
    
    func animateFlipBack() {
        isRunningPlayBack = true
        runFlipBackAnimation()
    }

    private var isInitial = true
    
    @objc
    private func displayLink() {
        if let drawable = (layer as? CAMetalLayer)?.nextDrawable() {
            renderer.render(to: drawable, with: curlParams)
            if isInitial {
                needsRender = false
                isInitial = false
            }
        }
    }
    
    @objc
    func move(gesture: UIPanGestureRecognizer) {
        if(gesture.state == UIGestureRecognizer.State.ended) {
            animateFlipBack()
            return
        }

        if gesture.state == .began {
            needsRender = true
        }

        let translation = gesture.translation(in: self)

        if PanGestureTransformer.shouldTransform(translation) {
            curlParams = transformer.transform(translation: translation, in: self.bounds)
        }
    }
    
    private func runFlipBackAnimation() {
        var currentDelta = curlParams.delta
        while(isRunningPlayBack) {
            if currentDelta - playBackStep <= 0 {
                currentDelta = 0
                currentDelta = 0
                isRunningPlayBack = false
                needsRender = false
            } else {
                currentDelta -= playBackStep
            }
            self.curlParams = CurlParams(phi: CGFloat(curlParams.phi), delta: CGFloat(currentDelta))
        }
    }
}
