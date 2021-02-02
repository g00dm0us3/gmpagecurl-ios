//
//  InputUtils.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 1/31/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import Foundation
import CoreGraphics

struct PanGestureTransformer {
    /// Maximum angle with x-axis, at which the page can be turned
    let maxPhi: CGFloat

    /// Maximum distance, from right, after which the page is considered to be turned
    /// Must be between 0 and 1.
    let turnPageDistanceThreshold: CGFloat

    /// Points to the right
    private let xAxis = CGPoint(x: 1, y: 0)

    private static let minVectorLength = CGFloat(0.0001)

    /// - Note: ```turnPageDistanceThreshold``` should be in (0,1] interval. Zero would mean that user had to start precisely at the right edge,
    /// and drag their finger all the way to the left, for the page to be considered turned. One would mean that as soon as user touches right edge of the page,
    /// the page is considered to be turned.
    /// - Note: For best user experience, avoid using boundary values for ```turnPageDistanceThreshold```
    init(maxPhi: CGFloat, turnPageDistanceThreshold: CGFloat) {
        guard turnPageDistanceThreshold > 0 && turnPageDistanceThreshold <= 2 else { fatalError("Wrong turn page threshold") }
        self.maxPhi = maxPhi
        self.turnPageDistanceThreshold = turnPageDistanceThreshold
    }

    static func shouldTransform(_ translation: CGPoint) -> Bool {
        return abs(translation.x) >= PanGestureTransformer.minVectorLength
    }

    /// Transforms pan gesture translation vector into parameters used for page curl rendering.
    @inline(__always)
    func transform(translation: CGPoint, in bounds: CGRect) -> CurlParams {
        guard abs(translation.x) >= PanGestureTransformer.minVectorLength else { fatalError("Translation vector too small") }
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
        let rtl = translation.x < 0
        var delta = CGFloat(0)

        // moving rtl
        if rtl {
            delta = normalized.rescale(0...1, newRange: 0...2)
        } else {
            delta = 2 - normalized.rescale(0...1, newRange: 0...2)
        }

        return CurlParams(phi: rads.clamp(to: -maxPhi...maxPhi), delta: delta.clamp(to: 0...turnPageDistanceThreshold))
    }

    /// Transofrms translation vector to the rotation angples around x and y axes.
    /// - Note: left for debug purposes.
    func debugTransform(translation: CGPoint, lastThetaX: CGFloat, lastThetaY: CGFloat, in bounds: CGRect) -> (thetaX: CGFloat, thataY: CGFloat) {
        let maxX = CGFloat(bounds.width / 2)
        let maxY = CGFloat(bounds.height / 2)

        let x = CGFloat(translation.x / 2)
        let y = CGFloat(translation.y / 2)

        var thetaX = (x/maxX)*2*CGFloat.pi
        var thetaY = (y/maxY)*2*CGFloat.pi

        func congruentAngle(_ radians: CGFloat) -> CGFloat {
            let numberOfFullRotations = radians / (2*CGFloat.pi)

            return radians - max((numberOfFullRotations-1)*2*CGFloat.pi, 0)
        }

        thetaX = congruentAngle(lastThetaX + thetaX)
        thetaY = congruentAngle(lastThetaY + thetaY)

        return (thetaX, thetaY)
    }
}

struct ScaleGestureTranformer {
    /// Given current and previous value of scale gesture, calculates the new scale
    /// - Note: For debug purposes only.
    func debugTransform(_ scale: CGFloat, lastScale: CGFloat) -> CGFloat {
        return scale*lastScale
    }
}
