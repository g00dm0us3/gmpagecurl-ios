//
//  GMPageCurlView.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 7/15/20.
//  Copyright © 2020 Homer. All rights reserved.
//

import UIKit
import MetalKit

protocol GMPageCurlViewDataSource: class {
    func pageCurlView(_ pageCurlView: GMPageCurlView) -> GMPageView
    func pageCurlView(_ pageCurlView: GMPageCurlView, updateView: GMPageView, for pageIndex: UInt32)
}

/// - TODO: implement sampleCount (MSAA)
final class GMPageCurlView: UIView {
    weak var datasource: GMPageCurlViewDataSource?
    
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
    
    private(set) var pageIndex = UInt32(0)
    
    private var pageViews = [GMPageView]()
    
    // MARK: Initializers
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
        self.caDisplayLink.isPaused = true
        /*let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(move))
        gestureRecognizer.minimumNumberOfTouches = 1
        gestureRecognizer.maximumNumberOfTouches = 1
        gestureRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(gestureRecognizer)*/
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    // MARK: Public Interface

    func reloadData() {
        guard let ds = datasource else { return }
        pageViews = []
        pageIndex = 0
        
        for _ in 0..<2 {
            let view = ds.pageCurlView(self)
            pageViews.append(view)
        }
        
        pageViews[0].frame = CGRect(origin: .zero, size: CGSize(width: 200, height: 300))
        addSubview(pageViews[0])
        addSubview(pageViews[1])
        
        bringSubviewToFront(pageViews[0])
        sendSubviewToBack(pageViews[1])
        needsRender = false
        curlParams = .noCurl
        ds.pageCurlView(self, updateView: pageViews[0], for: pageIndex)
        setNeedsDisplay()
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
        
        renderer.render(to: drawable, with: curlParams, viewTexture: placeholderTexture)
        
        if isRunningPlayBack {
            isRunningPlayBack = flipBackStep()
            needsRender = isRunningPlayBack
            isUserInteractionEnabled = !isRunningPlayBack
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
            let view = UIView(frame: CGRect(origin: .zero, size: CGSize(width: drawable.texture.width, height: drawable.texture.height)))
            view.backgroundColor = .white
            let label = UITextView(frame: CGRect(x: 8, y: 8, width: view.frame.width-8, height: view.frame.height - 8))
            label.backgroundColor = .clear
            label.text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

            view.addSubview(label)

            let imageRenderer = UIGraphicsImageRenderer(size: view.frame.size)

            let image = imageRenderer.image { (ctx) in
                view.layer.render(in: ctx.cgContext)
            }
            
            guard let device = (self.layer as? CAMetalLayer)?.device else { return }
            let textureLoader = MTKTextureLoader(device: device)
            placeholderTexture = try! textureLoader.newTexture(cgImage: image.cgImage!, options: nil)
        }
    }
}
