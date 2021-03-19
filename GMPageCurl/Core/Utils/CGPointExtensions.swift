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
    
    func deg2rad() -> CGFloat {
        return (CGFloat.pi * self) / 180
    }

    @inline(__always)
    func rescale(_ oldRange: ClosedRange<CGFloat>, newRange: ClosedRange<CGFloat>) -> CGFloat {
        let clamped = clamp(to: oldRange)

        let k = (newRange.upperBound-newRange.lowerBound)/(oldRange.upperBound-oldRange.lowerBound)
        let x = (clamped - oldRange.lowerBound)
        let b = newRange.lowerBound

        return k*x+b
    }

    @inline(__always)
    func clamp(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension CGPoint {
    @inline(__always)
    func length() -> CGFloat {
        return sqrt(x*x+y*y)
    }

    @inline(__always)
    func normalize() -> CGPoint {
        return CGPoint(x: x/self.length(), y: y/self.length())
    }

    @inline(__always)
    func dot(_ vec: CGPoint) -> CGFloat {
        return x*vec.x+y*vec.y
    }
    
    static func *(lhs: CGFloat, rhs: CGPoint) -> CGPoint{
        return CGPoint(x: lhs*rhs.x, y: lhs*rhs.y)
    }
}
