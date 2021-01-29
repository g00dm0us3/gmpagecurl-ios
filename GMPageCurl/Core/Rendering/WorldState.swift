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

fileprivate protocol ModeInput {
    var phi: Float { get }
    var distance: Float { get }
    
    func panned(_ translation: CGPoint, velocity: CGPoint) -> simd_float4x4
    func scaled(_ scale: Float) -> simd_float4x4
}

extension Renderer {
    final class WorldState {
        /// Alters, how the input is process
        fileprivate let isDevMode = true
    
        /// Constant
        let perspectiveMatrix: simd_float4x4
        let lightMatrix: simd_float4x4
        
        /// Variable
        
        private(set) var stateUpdated = true

        private(set) var worldMatrix: simd_float4x4
        var lightModelMatrix: simd_float3x3 {
            let lightModelMatrix = simd_float3x3([
                simd_float3(worldMatrix[0][0],worldMatrix[0][1],worldMatrix[0][2]),
                simd_float3(worldMatrix[1][0],worldMatrix[1][1],worldMatrix[1][2]),
                simd_float3(worldMatrix[2][0],worldMatrix[2][1],worldMatrix[2][2])]).inverse;
            return lightModelMatrix.transpose
        }
        
        var phi: Float {
            return modeInput.phi
        }
        
        var distance: Float {
            return modeInput.distance
        }
        
        private let modeInput: ModeInput
        
        init() {
            perspectiveMatrix = MatrixUtils.matrix_ortho(left: -1, right: 1, bottom: -1, top: 1, near: 1, far: -1)//MatrixUtils.matrix_perspective(aspect: 1, fovy: 90.0, near: 0.1, far: 100)

            let ortho = MatrixUtils.matrix_ortho(left: -1, right: 1, bottom: -1, top: 1, near: 1, far: -1)
            //let lightView = MatrixUtils.matrix_lookat(at: simd_float3(0,0,0), eye: simd_float3(0,0,-2), up: simd_float3(0,1,0))
            lightMatrix = ortho
            
            if isDevMode {
                modeInput = DebugModeInput()
            } else {
                modeInput = PaginationModeInput()
            }
            worldMatrix = MatrixUtils.identityMatrix4x4
            //worldMatrix = modeInput.scaled(1)
        }
        
        func worldPanned(_ translation: CGPoint, velocity: CGPoint) {
            
        }
        
        func worldScaled(_ scale: Float) {
            
        }
        
        func setStateProcessed() {
            stateUpdated = false
        }
    }
    
    fileprivate class PaginationModeInput: ModeInput {
        private(set) var phi = Float(0)
        private(set) var distance = Float(0)
        
        private let worldMatrix = MatrixUtils.identityMatrix4x4
        
        func panned(_ translation: CGPoint, velocity: CGPoint) -> simd_float4x4 {
            return worldMatrix
        }
        
        func scaled(_ scale: Float) -> simd_float4x4 {
            return worldMatrix
        }
    }
    
    fileprivate class DebugModeInput: ModeInput {
        private(set) var phi = Float(0)
        private(set) var distance = Float(0.7)
        
        private(set) var thetaX = Float(0)
        private(set) var thetaY = Float(0)
        
        private(set) var scale = Float(1)
        
        private var lastThetaX: Float = 0
        private var lastThetaY: Float = 0
        
        private var lastScale = Float(1)
        
        func panned(_ translation: CGPoint, velocity: CGPoint) -> simd_float4x4 {
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
            
            return worldMatrix()
        }
        
        func scaled(_ scale: Float) -> simd_float4x4 {
            self.scale = scale*lastScale
            lastScale = self.scale
            
            return worldMatrix()
        }
        
        private func worldMatrix() -> simd_float4x4 {
            let translation = MatrixUtils.matrix4x4Translate(t: simd_float3(arrayLiteral: 0, 0, -1.1))
            let scaleMatrix = MatrixUtils.matrix4x4Scale(scale: simd_float3(arrayLiteral: scale, scale, scale))

            let rotationMatrixX = MatrixUtils.matrix4x4RotateAroundX(theta: thetaY)
            let rotationMatrixY = MatrixUtils.matrix4x4RotateAroundY(theta: thetaX)

            return translation*scaleMatrix*rotationMatrixX*rotationMatrixY
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
}
