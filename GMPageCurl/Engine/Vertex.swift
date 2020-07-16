//
//  Vertex.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 3/16/19.
//  Copyright © 2019 g00dm0us3. All rights reserved.
//

import Foundation

struct Vertex
{

    var x, y, z: Float     // position data
    var r, g, b, a: Float   // color data

    func floatBuffer() -> [Float] {
        return [x, y, z, r, g, b, a]
    }
}
