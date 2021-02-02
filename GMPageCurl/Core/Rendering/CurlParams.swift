//
//  CurlParams.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 2/2/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import Foundation
import CoreGraphics

struct CurlParams: Equatable {
    let phi: Float
    let delta: Float
    
    static let noCurl = CurlParams(phi: 0, delta: 0)

    init(phi: CGFloat, delta: CGFloat) {
        self.phi = Float(phi)
        self.delta = Float(delta)
    }
}
