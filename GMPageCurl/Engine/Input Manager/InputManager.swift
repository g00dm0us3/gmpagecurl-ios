//
//  InputManager.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 7/16/20.
//  Copyright © 2020 Homer. All rights reserved.
//

import Foundation
import simd
import CoreGraphics

// - TODO: rotation
// - TODO: controlls for page turning
final class InputManager {
    static let defaultManager = InputManager()

    var replaying: Bool = false

    var displacement: Float = 0.4
    private(set) var phi: Float = 0

    var lastTouch: CGPoint = .zero
    var firstTouch: CGPoint = .zero
    private var lastTranslation: CGPoint = .zero

    private let screenWidth: Float = 325.0
    private let screenHeight: Float = 667.0

    var translation: CGPoint {
        set (newTranslation) {
            let vecX = Float(newTranslation.x - lastTouch.x)
            let vecY = Float(newTranslation.y - lastTouch.y)
            let filterFactor: Float = 0.98

            lastTouch = newTranslation

            let t = (screenWidth/2 - Float(firstTouch.x+newTranslation.x)) / screenWidth

            displacement =  -t

            var d = Float(displacement)
            var newPhi = (acos((abs(vecX))/(sqrt(vecX*vecX+vecY*vecY))))
            if case .minus = vecY.sign {newPhi *= -1 }

            //todo: filter phi signal for high frequencies
            if !newPhi.isNaN {
                //
                //newPhi = phi

                if newPhi > Float.pi/64 && newPhi <= Float.pi / 4 {
                    newPhi = Float.pi/8
                }
                if newPhi > Float.pi/4 && newPhi <= Float.pi/2 {
                    newPhi = 3*Float.pi/8
                }
                if newPhi > Float.pi/2 && newPhi <= Float.pi*3/4 {
                    newPhi = 4*Float.pi/8
                }
                if newPhi > Float.pi*3/4 && newPhi <= Float.pi {
                    newPhi = 5*Float.pi/8
                }
                newPhi = InputManager.rescale(val: newPhi, ra: Float.pi/8, rb: 5*Float.pi/8, na: -Float.pi/4, nb: Float.pi/4)
                phi = filterFactor * phi + (1.0 - filterFactor) * newPhi
            }

        }
        get {
            return lastTranslation
        }

    }

    func getDisplacement() -> Float {
        if(displacement == 1 && replaying) {
            replaying = false
            lastTouch = CGPoint.zero
            firstTouch = CGPoint.zero
        }

        if(replaying) {
            displacement += 0.05
        }

        return displacement
    }

    private(set) var worldMatrix = MatrixUtils.identityMatrix4x4

    private init() {
        phi = InputManager.degree2rad(degree: 42)

        worldMatrix = worldMatrix*MatrixUtils.matrix4x4Translate(t: simd_float3(arrayLiteral: 0, 0, -1.1))
        //worldMatrix = worldMatrix*MatrixUtils.matrix4x4Scale(scale: simd_float3(arrayLiteral: 1, 1, 1))
    }

    private static func degree2rad(degree: Float) -> Float {
        return (degree*Float.pi)/180.0
    }

    private static func rescale(val: Float, ra: Float, rb: Float, na: Float, nb: Float) -> Float {
        return (val-ra)*(nb-na)/(rb-ra)+na
    }
}
