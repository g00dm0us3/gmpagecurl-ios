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

        

        init() {
            perspectiveMatrix = MatrixUtils.matrix_ortho(left: -1, right: 1, bottom: -1, top: 1, near: 1, far: -1)//MatrixUtils.matrix_perspective(aspect: 1, fovy: 90.0, near: 0.1, far: 100)

            let ortho = MatrixUtils.matrix_ortho(left: -1, right: 1, bottom: -1, top: 1, near: 1, far: -1)
            //let lightView = MatrixUtils.matrix_lookat(at: simd_float3(0,0,0), eye: simd_float3(0,0,-2), up: simd_float3(0,1,0))
            lightMatrix = ortho

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
}
