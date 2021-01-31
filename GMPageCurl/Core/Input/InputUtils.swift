//
//  InputUtils.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 1/31/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import Foundation
import CoreGraphics

enum Input {
    struct PanGestureTransformer {
        /// Maximum angle with x-axis, at which the page can be turned
        let maxPhi: CGFloat
        
        /// Maximum distance, from right, after which the page is considered to be turned
        /// Must be between 0 and 1.
        let turnPageDistanceThreshold: CGFloat
        
        /// Points to the right
        private let xAxis = CGPoint(x: 1, y: 0)
        
        /// - Note: ```turnPageDistanceThreshold``` should be in (0,1] interval. Zero would mean that user had to start precisely at the right edge,
        /// and drag their finger all the way to the left, for the page to be considered turned. One would mean that as soon as user touches right edge of the page,
        /// the page is considered to be turned.
        /// - Note: For best user experience, avoid using boundary values for ```turnPageDistanceThreshold```
        init(maxPhi: CGFloat, turnPageDistanceThreshold: CGFloat) {
            guard turnPageDistanceThreshold > 0 && turnPageDistanceThreshold <= 2 else { fatalError("Wrong turn page threshold") }
            self.maxPhi = maxPhi
            self.turnPageDistanceThreshold = turnPageDistanceThreshold
        }
        
        /// Transforms pan gesture translation vector into parameters used for page curl rendering.
        func transform(translation: CGPoint, in bounds: CGRect) -> (phi: CGFloat, distanceFromRightEdge: CGFloat) {
            let dot = translation.normalize().dot(xAxis)
            
            var rads = CGFloat(0)
            
            if translation.x >= 0 {
                let mul = CGFloat(translation.y > 0 ? -1 : 1)
                rads = mul*acos(dot)
            } else {
                let mul = CGFloat(translation.y < 0 ? -1 : 1)
                rads = mul*(CGFloat.pi-acos(dot))
            }

            let normalized = abs(translation.x/bounds.width)
            let mul = CGFloat(translation.x < 0 ? -1 : 1)
            let distanceFromRight = 2 + mul*normalized.rescale(0...1, newRange: 0...2)
            
            return (rads.clamp(to: -maxPhi...maxPhi), distanceFromRight.clamp(to: 0...turnPageDistanceThreshold))
        }
    }
}
