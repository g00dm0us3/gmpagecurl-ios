//
//  RenderingLoop.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 3/16/19.
//  Copyright © 2019 g00dm0us3. All rights reserved.
//

import Foundation
import UIKit


class RenderingViewController: UIViewController {
    
    var renderer: Renderer;
    var cadDisplayLink: CADisplayLink!;
    
    var layerSizeDidUpdate: Bool!;
    
    var model:Model;

    
    init() {
        layerSizeDidUpdate = false;
        renderer = Renderer()
        model = Model()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        layerSizeDidUpdate = false;
        renderer = Renderer()
        model = Model()
        
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.addSublayer(renderer.metalLayer)
        view.contentScaleFactor = UIScreen.main.scale
        
        cadDisplayLink = CADisplayLink(target: self, selector: #selector(redraw))
        cadDisplayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
    }
    
    func startReplaying() {
        
    }
    
    @objc
    func redraw() {
        if(layerSizeDidUpdate) {
            let scale = view.window!.screen.scale
            var drawableSize = view.bounds.size
            
            drawableSize.width = drawableSize.width * scale
            drawableSize.height = drawableSize.height * scale
            
            layerSizeDidUpdate = false
            
        }
        
        renderer.render()
        
        renderer.resetCurrentDrawable()
    }
    
    override func viewDidLayoutSubviews() {
        layerSizeDidUpdate = true
        let parentSize  = view.bounds.size
        
        /*let frame = CGRect.init(x: (parentSize.width - minSize)/2.0,
         y: (parentSize.height - minSize)/2.0,
         width: minSize, height: minSize)*/
        
        let frame = CGRect.init(x: 0,
                                y: 0,
                                width: parentSize.width, height: parentSize.height)
        
        renderer.setMetalLayerFrame(frame: frame)
    }
    
}
