//
//  RenderingView.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 7/15/20.
//  Copyright © 2020 Homer. All rights reserved.
//

import UIKit

class RenderingView: UIView {

    override class var layerClass: AnyClass { return CAMetalLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)

        guard let mtlLayer = layer as? CAMetalLayer else { fatalError("This should be metal layer!") }

        mtlLayer.device = RenderingDevice.defaultDevice
        mtlLayer.pixelFormat = MTLPixelFormat.bgra8Unorm
        mtlLayer.isOpaque = false
        isOpaque = false
        
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

}
