//
//  GMPageCurlView.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 7/15/20.
//  Copyright © 2020 Homer. All rights reserved.
//

import UIKit
import MetalKit

protocol MetalCurlViewDelegate: class {
    func didStart(flipAnimation inView: MetalPageCurlView)
    func didFinish(flipAnimation inView: MetalPageCurlView)
}

/// - TODO: implement sampleCount (MSAA)
final class MetalPageCurlView: UIView {
    enum FlipDirection: Equatable {
        case unknown
        case forward
        case backward
        
        init(_ translation: CGPoint) {
            if translation.x > 0 {
                self = .backward
                return
            }
            self = .forward
        }
    }
    
    weak var delegate: MetalCurlViewDelegate?
    
    var isRunningAnimation: Bool {
        return flipDirection != .unknown
    }
    
    override var isHidden: Bool {
        get { return super.isHidden }
        set {
            super.isHidden = newValue
            caDisplayLink.isPaused = newValue
        }
    }
    
    private var curlParams = CurlParams(phi: 0, delta: 0)
    
    private var renderer: CurlRenderer
    override class var layerClass: AnyClass { return CAMetalLayer.self }

    private var caDisplayLink: CADisplayLink!
    private let transformer = PanGestureTransformer(maxPhi: CGFloat.pi/3, turnPageDistanceThreshold: 1.8)
    private let playBackStep = Float(0.09)

    private var placeholderTexture: MTLTexture!
    private var inflightPage: MTLTexture?
    
    private var flipDirection = FlipDirection.unknown
    // MARK: Initializers
    override init(frame: CGRect) {
        self.renderer = CurlRenderer()

        super.init(frame: frame)
        guard let mtlLayer = layer as? CAMetalLayer else { fatalError("This should be metal layer!") }

        mtlLayer.device = DeviceWrapper.device
        mtlLayer.pixelFormat = MTLPixelFormat.bgra8Unorm
        mtlLayer.contentsScale = 2.0
        isOpaque = false
        mtlLayer.isOpaque = false
        self.caDisplayLink = CADisplayLink(target: self, selector: #selector(displayLink))
        self.caDisplayLink.add(to: .current, forMode: .default)
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    // MARK: Public interface
    func beginFlip(with pageImage: CGImage, flipDirection: FlipDirection) {
        guard !isRunningAnimation else { return }
        
        let textureLoader = MTKTextureLoader(device: DeviceWrapper.device)
       // do {
        inflightPage = try! textureLoader.newTexture(cgImage: pageImage, options: nil)
        isHidden = false
        self.flipDirection = flipDirection
    }
    
    func updateFlip(translation: CGPoint) {
        guard !isRunningAnimation else { return }
        if PanGestureTransformer.shouldTransform(translation) {
            curlParams = transformer.transform(translation: translation, in: self.bounds)
        }
    }
    
    func endFlip(flipAnimationThreshold: PageTurnProgress) {
        let raw = flipAnimationThreshold.rawValue
        guard !isRunningAnimation else { return }
        
        if self.flipDirection == .forward {
            if raw <= curlParams.delta {
                self.flipDirection = .backward
            } else {
                self.flipDirection = .forward
            }
        } else {
            /// - todo: should do the same check here, as above (animation threshold)
            self.flipDirection = .backward
        }
        isUserInteractionEnabled = false
        if isRunningAnimation {
            delegate?.didStart(flipAnimation: self)
        }
    }

    @objc
    private func displayLink() {
        guard let drawable = (layer as? CAMetalLayer)?.nextDrawable() else { return }
        buildPlaceholderTexture(drawable)
        
        if let tex = inflightPage {
            renderer.render(to: drawable, with: curlParams, viewTexture: tex)
        } else {
            renderer.render(to: drawable, with: curlParams, viewTexture: placeholderTexture)
        }
        
        /// - todo: flip direction not enough, to see if animation should roll
        switch flipDirection {
        
        }
        
        if isRunningFlipForward {
            isRunningFlipForward = flipForwardStep()
            if !isRunningFlipForward {
                inflightPage = nil
                isHidden = true
            }
            flipDirection = .unknown
        }
        
        if isRunningPlayBack {
            isRunningPlayBack = flipBackStep()
            
            if !isRunningPlayBack {
                inflightPage = nil
                isHidden = true
            }
            flipDirection = .unknown
        }
        
        if !isRunningAnimation {
            delegate?.didFinish(flipAnimation: self)
        }
    }

    private func flipBackStep() -> Bool {
        guard curlParams != .noCurl else { return false}
        
        var newParams = CurlParams.noCurl
        if curlParams.delta - playBackStep > 0 {
            newParams = CurlParams(phi: CGFloat(curlParams.phi), delta: CGFloat(curlParams.delta - playBackStep))
        }
        
        curlParams = newParams
        
        return true
    }
    
    private func flipForwardStep() -> Bool {
        guard curlParams != .noCurl else { return false}
        
        var newParams = CurlParams.noCurl
        if curlParams.delta + playBackStep < 2.0 {
            newParams = CurlParams(phi: CGFloat(curlParams.phi), delta: CGFloat(curlParams.delta + playBackStep))
        }
        
        curlParams = newParams
        
        return true
    }
    
    private func buildPlaceholderTexture(_ drawable: CAMetalDrawable) {
        guard placeholderTexture == nil else { return }
        if placeholderTexture == nil {

            let view = UIView(frame: CGRect(origin: .zero, size: frame.size))
            view.backgroundColor = .cyan

            let imageRenderer = UIGraphicsImageRenderer(size: view.frame.size)
        
            let image = imageRenderer.image { (ctx) in
                view.layer.render(in: ctx.cgContext)
            }
            
            let textureLoader = MTKTextureLoader(device: DeviceWrapper.device)
            placeholderTexture = try! textureLoader.newTexture(cgImage: image.cgImage!, options: nil)
        }
    }
}
