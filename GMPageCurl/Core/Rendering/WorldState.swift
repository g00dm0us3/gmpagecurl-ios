//
//  WorldState.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 1/29/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import Foundation
import UIKit
import simd

extension Renderer {
    final class WorldState {
        /// Alters, how the input is process
        fileprivate let isDevMode = true
    
        /// Constant
        let perspectiveMatrix: simd_float4x4
        let lightMatrix: simd_float4x4
        
        /// Variable
        
        private(set) var stateUpdated = true
        
        var renderingViewState: RenderViewStates = .cylinder {
            didSet {
                stateUpdated = oldValue == renderingViewState
            }
        }
        
        var worldMatrix: simd_float4x4 {
            let translation = MatrixUtils.matrix4x4Translate(t: simd_float3(arrayLiteral: 0, 0, -1.1))
            let scaleMatrix = MatrixUtils.matrix4x4Scale(scale: simd_float3(arrayLiteral: scale, scale, scale))

            let rotationMatrixX = MatrixUtils.matrix4x4RotateAroundX(theta: thetaY)
            let rotationMatrixY = MatrixUtils.matrix4x4RotateAroundY(theta: thetaX)

            return translation*scaleMatrix*rotationMatrixX*rotationMatrixY
        }
        
        private(set) var phi: Float = 0
        private(set) var radius: Float = 0
        
        init() {
            perspectiveMatrix = MatrixUtils.matrix_perspective(aspect: 1, fovy: 90.0, near: 0.1, far: 100)
            MatrixUtils.printMatrix(perspectiveMatrix)
            
            let ortho = MatrixUtils.matrix_ortho(left: -1, right: 1, bottom: -1, top: 1, near: 1, far: -1)
            let lightView = MatrixUtils.matrix_lookat(at: simd_float3(0,0,0), eye: simd_float3(0,0,-1), up: simd_float3(0,1,0))
            lightMatrix = ortho * lightView
        }
        
        func worldPanned(_ translation: CGPoint, velocity: CGPoint) {
            
        }
        
        func worldScaled(_ scale: Float) {
            
        }
        
        func setStateProcessed() {
            stateUpdated = false
        }
    }
    
    fileprivate class DevModeInput {
        private(set) var thetaX = Float(0)
        private(set) var thetaY = Float(0)
        
        private(set) var scale = Float(1)
        
        private var lastThetaX: Float = 0
        private var lastThetaY: Float = 0
        
        private var lastScale = Float(1)
        
        func updateRotation(_ translation: CGPoint) {
            let maxX = Float(UIScreen.main.bounds.maxX / 2)
            let maxY = Float(UIScreen.main.bounds.maxY / 2)

            let x = Float(translation.x / 2)
            let y = Float(translation.y / 2)

            let thetaX = (x/maxX)*2*Float.pi
            let thetaY = (y/maxY)*2*Float.pi

            self.thetaX = Utils.congruentAngle(lastThetaX + thetaX)
            self.thetaY = Utils.congruentAngle(lastThetaY + thetaY)
            
            lastThetaX = self.thetaX
            lastThetaY = self.thetaY
        }
        
        func updateScale(_ scale: Float) {
            self.scale = scale*lastScale
            lastScale = self.scale
        }
    }
    
    fileprivate struct Utils {
        /**
         Reduce the number of rations to at most 1
         */
        @inline(__always) static func congruentAngle(_ radians: Float) -> Float {
            let numberOfFullRotations = radians / (2*Float.pi)

            if (numberOfFullRotations <= 1) {
                return radians
            }

            return radians - (numberOfFullRotations-1)*2*Float.pi
        }

        static func degree2rad(degree: Float) -> Float {
            return (degree*Float.pi)/180.0
        }

        static func rescale(val: Float, ra: Float, rb: Float, na: Float, nb: Float) -> Float {
            return (val-ra)*(nb-na)/(rb-ra)+na
        }
    }
}
