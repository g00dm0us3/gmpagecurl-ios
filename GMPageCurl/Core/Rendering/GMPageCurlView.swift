//
//  GMPageCurlView.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 2/4/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import UIKit

protocol GMPageCurlDatasource: class {
    func makePageView() -> UIView
    func updatePageView(_ view: UIView, pageIndex: UInt32, numberOfPages: UInt32)
    func numberOfPages() -> UInt32
}

final class GMPageCurlView: UIView {
    
    weak var dataSource: GMPageCurlDatasource?
    
    private(set) var pageIndex = UInt32(0)
    private(set) var numberOfPages = UInt32(0)
    
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
        offScreenPage?.removeFromSuperview()
        onScreenPage = nil
        offScreenPage = nil
        pageIndex = 0
        
        guard let ds = dataSource else { return }
       
        onScreenPage = ds.makePageView()
        offScreenPage = ds.makePageView()
        
        addSubview(onScreenPage!)
        onScreenPage?.translatesAutoresizingMaskIntoConstraints = true
        onScreenPage?.frame = bounds
        onScreenPage?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sendSubviewToBack(onScreenPage!)
        
        addSubview(offScreenPage!)
        offScreenPage?.translatesAutoresizingMaskIntoConstraints = true
        offScreenPage?.frame = bounds
        offScreenPage?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sendSubviewToBack(offScreenPage!)
        
        numberOfPages = ds.numberOfPages()
        
        ds.updatePageView(onScreenPage!, pageIndex: pageIndex, numberOfPages: numberOfPages)
        ds.updatePageView(offScreenPage!, pageIndex: pageIndex, numberOfPages: numberOfPages)
    }
    
    @objc
    private func panHandler(gesture: UIPanGestureRecognizer) {
        var translation = gesture.translation(in: self)
        let translationLength = translation.length().clamp(to: 0.1...CGFloat.greatestFiniteMagnitude)
        
        translation = translationLength*translation.normalize()
        
        let flipDirection = FlipDirection(translation)
        
        guard !(flipDirection == .backward && pageIndex == 0) else { return }
        guard !(flipDirection == .forward && pageIndex == numberOfPages) else { return }
        
        if gesture.state == .began {
            // intentially not using topSubview's frame here, since if it doesn't match the size
            // of curl view, the behavior is pretty much undefined (book has non-uniform page sizes)
            let imageRenderer = UIGraphicsImageRenderer(size: frame.size)

            var image = UIImage()
            
            if flipDirection == .forward {
            
                image = imageRenderer.image { (ctx) in
                    self.layer.render(in: ctx.cgContext)
                }
                
                pageIndex += 1
                dataSource?.updatePageView(onScreenPage!, pageIndex: pageIndex, numberOfPages: numberOfPages)
            }
            
            
            if flipDirection == .backward {
                pageIndex -= 1
                dataSource?.updatePageView(offScreenPage!, pageIndex: pageIndex, numberOfPages: numberOfPages)
                
                image = imageRenderer.image { (ctx) in
                    self.offScreenPage!.layer.render(in: ctx.cgContext)
                }
            }
            
            //isUserInteractionEnabled = false // gr wouldn't work if this is tampered with. 0 idea why.
            
            metalPageCurlView.beginFlip(with: image.cgImage!, flipDirection: flipDirection)
            return
        }
        
        if gesture.state == .changed {
            metalPageCurlView.updateFlip(translation: translation)
            return
        }
        
        metalPageCurlView.endFlip()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension GMPageCurlView: MetalCurlViewDelegate {
    func willFinish(flipAnimationDirection: FlipDirection) {
        guard flipAnimationDirection == .backward else { return }
        dataSource?.updatePageView(onScreenPage!, pageIndex: pageIndex, numberOfPages: numberOfPages)
    }
    
    func didStart(flipAnimationDirection: FlipDirection) {
        return
    }
    
    func didFinish(flipAnimationDirection: FlipDirection) {
        isUserInteractionEnabled = true
    }
}
