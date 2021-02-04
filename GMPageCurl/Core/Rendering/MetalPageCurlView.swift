//
//  GMPageCurlView.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 7/15/20.
//  Copyright © 2020 Homer. All rights reserved.
//

import UIKit
import MetalKit

/// - TODO: implement sampleCount (MSAA)
final class MetalPageCurlView: UIView {
    
    override var isHidden: Bool {
        get { return super.isHidden }
        set {
            super.isHidden = newValue
            caDisplayLink.isPaused = newValue
        }
    }
    
    private var curlParams = CurlParams(phi: 0, delta: 0) {
        didSet {
            needsRender = true
        }
    }
    
    private var renderer: CurlRenderer
    override class var layerClass: AnyClass { return CAMetalLayer.self }

    private var isRunningPlayBack = false
    private var needsRender: Bool {
        didSet {
            caDisplayLink?.isPaused = !needsRender
        }
    }

    private var caDisplayLink: CADisplayLink!
    private let transformer = PanGestureTransformer(maxPhi: CGFloat.pi/3, turnPageDistanceThreshold: 1.5)
    private let playBackStep = Float(0.09)

    private var placeholderTexture: MTLTexture!
    private var inflightPage: MTLTexture?
    //private let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(move))
    
    // MARK: Initializers
    override init(frame: CGRect) {
        self.renderer = CurlRenderer()
        self.needsRender = true

        super.init(frame: frame)
        guard let mtlLayer = layer as? CAMetalLayer else { fatalError("This should be metal layer!") }

        mtlLayer.device = DeviceWrapper.device
        mtlLayer.pixelFormat = MTLPixelFormat.bgra8Unorm
        mtlLayer.contentsScale = 2.0
        isOpaque = false
        mtlLayer.isOpaque = false
        self.caDisplayLink = CADisplayLink(target: self, selector: #selector(displayLink))
        self.caDisplayLink.add(to: .current, forMode: .default)

        /*gestureRecognizer.minimumNumberOfTouches = 1
        gestureRecognizer.maximumNumberOfTouches = 1
        gestureRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(gestureRecognizer)*/
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    // MARK: Public interface
    func beginFlip(from translation: CGPoint, pageImage: CGImage) {
        let textureLoader = MTKTextureLoader(device: DeviceWrapper.device)
       // do {
        //inflightPage = try textureLoader.newTexture(cgImage: pageImage, options: nil)
        isHidden = false
        //gestureRecognizer.setTranslation(translation, in: self)
        //let touch = UITouch()
        //gestureRecognizer.touchesBegan(<#T##touches: Set<UITouch>##Set<UITouch>#>, with: <#T##UIEvent#>)
        //curlParams = transformer.transform(translation: translation, in: self.bounds)
        //} catch let e {
          //  let nse = e as? NSError
            //print("Failed to create tex.")
        //}
    }

    // MARK: Private Interface
    private func animateFlipBack() {
        isRunningPlayBack = true
        isUserInteractionEnabled = false
        needsRender = true
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
        
        if isRunningPlayBack {
            isRunningPlayBack = flipBackStep()
            needsRender = isRunningPlayBack
            isUserInteractionEnabled = !isRunningPlayBack
            
            if !isRunningPlayBack {
                // delegate call
                inflightPage = nil
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

    private func flipBackStep() -> Bool {
        guard curlParams != .noCurl else { return false}
        
        var newParams = CurlParams.noCurl
        if curlParams.delta - playBackStep > 0 {
            newParams = CurlParams(phi: CGFloat(curlParams.phi), delta: CGFloat(curlParams.delta - playBackStep))
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
            guard let device = (self.layer as? CAMetalLayer)?.device else { return }
            placeholderTexture = try! textureLoader.newTexture(cgImage: image.cgImage!, options: nil)
        }
    }
}
