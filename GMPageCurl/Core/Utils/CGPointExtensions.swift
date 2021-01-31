//
//  CGPointExtensions.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 1/31/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import Foundation
import CoreGraphics

extension CGFloat {
    func rad2deg() -> CGFloat {
        return (self * 180) / CGFloat.pi
    }

    func rescale(_ oldRange: ClosedRange<CGFloat>, newRange: ClosedRange<CGFloat>) -> CGFloat {
        let clamped = self.clamp(to: oldRange)

        let k = (newRange.upperBound-newRange.lowerBound)/(oldRange.upperBound-oldRange.lowerBound)
        let x = (clamped - oldRange.lowerBound)
        let b = newRange.lowerBound

        return k*x+b
    }

    func clamp(to range: ClosedRange<CGFloat>) -> CGFloat {
        var clamped = self
        if clamped < range.lowerBound {
            clamped = range.lowerBound
        } else if clamped > range.upperBound {
            clamped = range.upperBound
        }

        return clamped
    }
}

extension CGPoint {
    func length() -> CGFloat {
        return sqrt(x*x+y*y)
    }

    func normalize() -> CGPoint {
        return CGPoint(x: x/self.length(), y: y/self.length())
    }

    func dot(_ vec: CGPoint) -> CGFloat {
        return x*vec.x+y*vec.y
    }
}
