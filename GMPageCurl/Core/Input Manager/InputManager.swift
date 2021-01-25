//
//  InputManager.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 1/25/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import Foundation
import CoreGraphics
import simd

enum RenderViewStates: Int {
    case box = 1, cylinder = 0
}

protocol InputManager {
    var renderingViewState: RenderViewStates { get set }
    
    var worldMatrix: simd_float4x4 { get }
    
    var phi: CGFloat { get }
    
    var radius: CGFloat { get }
    
    func panGestureChanged(_ translation: CGPoint, velocity: CGPoint)
    func panGestureEnded()

    func pinchGestureChanged(_ scale: Float)
    func pinchGestureEnded()
}
