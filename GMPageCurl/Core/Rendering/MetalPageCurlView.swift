//
//  GMPageCurlView.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 7/15/20.
//  Copyright © 2020 Homer. All rights reserved.
//

import UIKit
import MetalKit

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

protocol MetalCurlViewDelegate: class {
    func didStart(flipAnimationDirection: FlipDirection)
    func didFinish(flipAnimationDirection: FlipDirection)
    func willFinish(flipAnimationDirection: FlipDirection)
}

/// - TODO: implement sampleCount (MSAA)
final class MetalPageCurlView: UIView {
    
    weak var delegate: MetalCurlViewDelegate?
    
    private(set) var isRunningAnimation = false
    
    private(set) var flipDirection = FlipDirection.unknown
    
    override var isHidden: Bool {
        get { return super.isHidden }
        set {
            super.isHidden = newValue
            caDisplayLink.isPaused = newValue
            
            if isHidden {
                isRunningAnimation = false
                curlParams = .noCurl
            }
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
        guard !isRunningAnimation else { print("⚠️ Trying to begin flip while animation is running"); return }
        
        let textureLoader = MTKTextureLoader(device: DeviceWrapper.device)
        inflightPage = try! textureLoader.newTexture(cgImage: pageImage, options: nil)
        isHidden = false
        self.flipDirection = flipDirection
    }
    
    func updateFlip(translation: CGPoint) {
        guard !isRunningAnimation else { print("⚠️ Trying to update flip while animation is running"); return }
        if PanGestureTransformer.shouldTransform(translation) {
            curlParams = transformer.transform(translation: translation, in: self.bounds)
        }
    }
    
    func endFlip() {
        guard !isRunningAnimation else { print("⚠️ Trying to end flip while animation is running"); return }

        isRunningAnimation = true
        isUserInteractionEnabled = false
        if isRunningAnimation {
            delegate?.didStart(flipAnimationDirection: flipDirection)
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

        if isRunningAnimation {
            switch flipDirection {
            case .forward:
                isRunningAnimation = flipForwardStep()
            case .backward:
                isRunningAnimation = flipBackStep()
            case .unknown:
                isRunningAnimation = false
            }
            
            if isLastFlipAnimationStep() {
                delegate?.willFinish(flipAnimationDirection: flipDirection)
            }
            
            if !isRunningAnimation {
                inflightPage = nil
                isHidden = true
                delegate?.didFinish(flipAnimationDirection: flipDirection)
                flipDirection = .unknown
            }
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
    
    private func isLastFlipAnimationStep() -> Bool {
        if flipDirection == .backward {
            return !(curlParams.delta - playBackStep > 0)
        } else {
            return !(curlParams.delta + playBackStep < 2.0)
        }
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
