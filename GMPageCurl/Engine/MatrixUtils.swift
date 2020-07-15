//
//  MatrixUtils.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 4/26/19.
//  Copyright © 2019 Homer. All rights reserved.
//

import Foundation
import GLKit

struct MatrixUtils {

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
    
    /// - todo: rotation around origin
    
    static func matrix_perspective(aspect: Float, fovy: Float, near: Float, far: Float) -> simd_float4x4
    {
        let rad = fovy*Float.pi / 180.0
        
        let yScale = 1 / tan(rad * 0.5);
        let xScale = yScale / aspect;
        let zRange = far - near;
        let zScale = -(far + near) / zRange;
        let wzScale = -2 * far * near / zRange;

        return simd_float4x4([
            float4(arrayLiteral: xScale, 0, 0, 0),
            float4(arrayLiteral: 0, yScale, 0, 0),
            float4(arrayLiteral: 0, 0, zScale, -1),
            float4(0, 0, wzScale, 0)
        ])
    }
}
