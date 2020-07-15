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
    
    static func glk4x4tosimd(mat: GLKMatrix4) -> simd_float4x4 {
    
        return simd_float4x4([
            float4(arrayLiteral: mat.m00, mat.m01, mat.m02, mat.m03),
            float4(arrayLiteral: mat.m10, mat.m11, mat.m12, mat.m13),
            float4(arrayLiteral: mat.m20, mat.m21, mat.m22, mat.m23),
            float4(arrayLiteral: mat.m30, mat.m31, mat.m32, mat.m33)
            ])
    }
    
    static func glk3x3tosimd(mat: GLKMatrix3) -> simd_float3x3 {
        
        return simd_float3x3([
            float3(arrayLiteral: mat.m00, mat.m01, mat.m02),
            float3(arrayLiteral: mat.m10, mat.m11, mat.m12),
            float3(arrayLiteral: mat.m20, mat.m21, mat.m22)
            ])
    }
    
    static var matrix4x4Size: Int {
        return MemoryLayout<simd_float4x4>.size
    }
}
