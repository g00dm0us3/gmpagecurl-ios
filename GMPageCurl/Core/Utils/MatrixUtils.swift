//
//  MatrixUtils.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 4/26/19.
//  Copyright © 2019 Homer. All rights reserved.
//

import Foundation
import CoreGraphics
import simd

enum MatrixUtils {

    static var matrix4x4Size: Int {
        return MemoryLayout<simd_float4x4>.size
    }

    static var identityMatrix4x4: simd_float4x4 {
        return simd_float4x4([
            float4(arrayLiteral: 1, 0, 0, 0),
            float4(arrayLiteral: 0, 1, 0, 0),
            float4(arrayLiteral: 0, 0, 1, 0),
            float4(arrayLiteral: 0, 0, 0, 1)
        ])
    }

    static func matrix4x4Translate(t: simd_float3) -> simd_float4x4 {
        return simd_float4x4([
            float4(arrayLiteral: 1, 0, 0, 0),
            float4(arrayLiteral: 0, 1, 0, 0),
            float4(arrayLiteral: 0, 0, 1, 0),
            float4(arrayLiteral: t.x, t.y, t.z, 1)
        ])
    }

    static func matrix4x4Scale(scale: simd_float3) -> simd_float4x4 {
        return simd_float4x4([
            float4(arrayLiteral: scale.x, 0, 0, 0),
            float4(arrayLiteral: 0, scale.y, 0, 0),
            float4(arrayLiteral: 0, 0, scale.z, 0),
            float4(arrayLiteral: 0, 0, 0, 1)
        ])
    }

    static func matrix4x4RotateAroundX(theta: Float) -> simd_float4x4 {
        return simd_float4x4([
            float4(arrayLiteral: 1, 0, 0, 0),
            float4(arrayLiteral: 0, cosf(theta), -sinf(theta), 0),
            float4(arrayLiteral: 0, sinf(theta), cosf(theta), 0),
            float4(arrayLiteral: 0, 0, 0, 1)
        ])
    }

    static func matrix4x4RotateAroundY(theta: Float) -> simd_float4x4 {
        return simd_float4x4([
            float4(arrayLiteral: cosf(theta), 0, sinf(theta), 0),
            float4(arrayLiteral: 0, 1, 0, 0),
            float4(arrayLiteral: -sinf(theta), 0, cosf(theta), 0),
            float4(arrayLiteral: 0, 0, 0, 1)
        ])
    }

    static func matrix_perspective(aspect: Float, fovy: Float, near: Float, far: Float) -> simd_float4x4 {
        let rad = fovy*Float.pi / 180.0

        let yScale = 1 / tan(rad * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near
        let zScale = -(far + near) / zRange
        let wzScale = -2 * far * near / zRange

        return simd_float4x4([
            float4(arrayLiteral: xScale, 0, 0, 0),
            float4(arrayLiteral: 0, yScale, 0, 0),
            float4(arrayLiteral: 0, 0, zScale, -1),
            float4(0, 0, wzScale, 0)
        ])
    }

    static func matrix_ortho(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> simd_float4x4 {
        return simd_float4x4([
            float4(arrayLiteral: 2/(right-left), 0, 0, 0),
            float4(arrayLiteral: 0, 2/(top-bottom), 0, 0),
            float4(arrayLiteral: 0, 0, 1 / (far - near), 0),
            float4(arrayLiteral: (left+right) / (left - right), (top + bottom) / (bottom - top), near / (near - far), 1)
        ])
    }

    static func matrix_lookat(at: simd_float3, eye: simd_float3, up: simd_float3) -> simd_float4x4 {
        let zaxis = normalize(at - eye)
        let xaxis = normalize(cross(up, zaxis))
        let yaxis = cross(zaxis, xaxis)

        return simd_float4x4([
            float4(arrayLiteral: xaxis.x, yaxis.x, zaxis.x, 0),
            float4(arrayLiteral: xaxis.y, yaxis.y, zaxis.y, 0),
            float4(arrayLiteral: xaxis.z, yaxis.z, zaxis.z, 0),
            float4(arrayLiteral: -dot(xaxis, eye), -dot(yaxis, eye), -dot(zaxis, eye), 1)
        ])
    }

    static func printMatrix(_ m: simd_float4x4) {
        for i in 0..<4 {
            print("[ \(m[i][0]) \(m[i][1]) \(m[i][2]) \(m[i][3]) ]")
        }
    }

    /// Builds a  world matrix, given rotation around x, y axes and scale
    /// - Note: for debug purposes only.
    static func worldMatrix(thetaX: CGFloat, thetaY: CGFloat, scale: CGFloat) -> simd_float4x4 {
        let translation = MatrixUtils.matrix4x4Translate(t: simd_float3(arrayLiteral: 0, 0, -1.1))
        let scaleMatrix = MatrixUtils.matrix4x4Scale(scale: simd_float3(arrayLiteral: Float(scale), Float(scale), Float(scale)))

        let rotationMatrixX = MatrixUtils.matrix4x4RotateAroundX(theta: Float(thetaX))
        let rotationMatrixY = MatrixUtils.matrix4x4RotateAroundY(theta: Float(thetaY))

        return translation*scaleMatrix*rotationMatrixX*rotationMatrixY
    }
}
