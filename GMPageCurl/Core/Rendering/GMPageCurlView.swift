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
        mtlLayer.contentsScale = 2.0
        isOpaque = false
        mtlLayer.isOpaque = false
        self.caDisplayLink = CADisplayLink(target: self, selector: #selector(displayLink))
        self.caDisplayLink.add(to: .current, forMode: .default)
        //self.caDisplayLink.isPaused = true
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
            // - todo: frames
            let view = UIView(frame: CGRect(origin: .zero, size: CGSize(width: frame.width, height: frame.height)))
            view.backgroundColor = .white
            let label = UITextView(frame: CGRect(x: 0, y: 0, width: view.frame.width-0, height: view.frame.height - 0))
            label.backgroundColor = .clear
            label.font = UIFont.systemFont(ofSize: 14)
            label.text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut vitae bibendum nisi, in laoreet leo. Curabitur pulvinar quam ac nulla volutpat, et aliquam neque vulputate. Sed mollis leo at orci faucibus pellentesque. Curabitur posuere enim non ex accumsan suscipit. Fusce ante ante, viverra at mauris id, auctor hendrerit magna. Mauris mollis ipsum ac diam vehicula, nec consequat nisl dictum. Nunc egestas lectus eget est efficitur accumsan. Aenean convallis rhoncus metus sit amet ullamcorper. Cras quis facilisis odio. Nam vestibulum efficitur auctor. Pellentesque non ullamcorper nisi. Mauris consequat, nisi nec volutpat pellentesque, diam ipsum condimentum risus, eget mattis libero elit eget mi. In eget lacinia erat. Aliquam velit lectus, dapibus eget sem ut, varius maximus ipsum. Aenean posuere semper enim sit amet finibus. Mauris quis aliquam dui, ac luctus lacus. Donec hendrerit vehicula odio ac vestibulum. Nullam ipsum metus, vestibulum eleifend molestie in, tincidunt nec est. Pellentesque euismod varius mauris, vel mattis dolor consequat ut. Sed eu risus arcu. Interdum et malesuada fames ac ante ipsum primis in faucibus. Mauris erat leo, mattis id est quis, aliquam ultricies ante. Etiam at felis ornare est luctus fringilla eget sit amet augue. Sed a ultricies nibh. Donec egestas pellentesque ullamcorper. Phasellus at dapibus tortor, et condimentum magna. Suspendisse in neque ligula. Nullam commodo in lectus in porttitor. Ut consequat magna eget semper vehicula. Sed rutrum mollis pulvinar. Sed luctus risus convallis, pharetra felis ut, sodales enim. In lacinia metus eu sem bibendum porttitor id ac augue. Donec id iaculis mauris, a tristique nibh. Nullam eget ex dictum, tempor nisl at, lacinia erat. Morbi eleifend, augue sed ultrices blandit, tortor nunc efficitur magna, ut molestie elit est vitae mi. Vestibulum vel nulla ex. Duis at laoreet dui. Mauris dapibus, velit sed cursus tincidunt, risus velit rhoncus nibh, a ultricies elit neque at libero. Vestibulum purus ligula, laoreet sed purus aliquet, facilisis gravida lorem. Cras luctus libero sed justo elementum pellentesque. Cras aliquet tellus metus, ac sodales lorem pretium non. Suspendisse vitae elementum odio. Nunc nec odio cursus, rhoncus risus ac, hendrerit ante. Pellentesque efficitur erat vel dapibus aliquam. Duis venenatis dui at luctus tincidunt. Integer vel egestas mauris, et mattis justo. Nullam ut felis purus.  Donec nisi ipsum, suscipit vitae purus in, commodo vulputate ligula. Aenean lacinia dolor quis augue rhoncus, ac dapibus justo varius. Curabitur consectetur lorem et libero rutrum dignissim. Interdum et malesuada fames ac ante ipsum primis in faucibus. Pellentesque ornare justo in gravida lobortis. Cras scelerisque, odio eu rhoncus tincidunt, orci lacus rhoncus magna, ut efficitur dui neque non felis. Nulla mattis ullamcorper bibendum."

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
