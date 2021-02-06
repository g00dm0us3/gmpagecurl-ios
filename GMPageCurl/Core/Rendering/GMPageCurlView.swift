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
    func updatePageView(_ view: UIView, pageIndex: UInt32)
}

final class GMPageCurlView: UIView {
    
    weak var dataSource: GMPageCurlDatasource?
    
    private(set) var currentPageIndex = UInt32(100)
    
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
        currentPageIndex = 100
        
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
        
        ds.updatePageView(onScreenPage!, pageIndex: currentPageIndex)
        ds.updatePageView(offScreenPage!, pageIndex: currentPageIndex)
    }
    
    var y = 0
    @objc
    private func panHandler(gesture: UIPanGestureRecognizer) {
        y += 1
        let translation = gesture.translation(in: self)
        
        let flipDirection = FlipDirection(translation)
        
        guard !(flipDirection == .backward && currentPageIndex == 0) else { return }
        
        if gesture.state == .began {
            // intentially not using topSubview's frame here, since if it doesn't match the size
            // of curl view, the behavior is pretty much undefined (book has non-uniform page sizes)
            let imageRenderer = UIGraphicsImageRenderer(size: frame.size)

            var image = UIImage()
            
            if flipDirection == .forward {
            
                image = imageRenderer.image { (ctx) in
                    self.layer.render(in: ctx.cgContext)
                }
                
                currentPageIndex += 1
                dataSource?.updatePageView(onScreenPage!, pageIndex: currentPageIndex)
            }
            
            
            if flipDirection == .backward {
                currentPageIndex -= 1
                dataSource?.updatePageView(offScreenPage!, pageIndex: currentPageIndex)
                
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
        dataSource?.updatePageView(onScreenPage!, pageIndex: currentPageIndex)
    }
    
    func didStart(flipAnimationDirection: FlipDirection) {
        return
    }
    
    func didFinish(flipAnimationDirection: FlipDirection) {
        isUserInteractionEnabled = true
    }
}
