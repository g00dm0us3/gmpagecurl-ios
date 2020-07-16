//
//  Model.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 3/16/19.
//  Copyright © 2019 g00dm0us3. All rights reserved.
//

import Foundation
import Metal
import simd
import CoreGraphics

final class Model {

    private let rows = 23
    private let columns = 20

    lazy var serializedVertexData: [Float] = {
        var vd = [Float]()

        for vertex in vertexData {
            vd.append(contentsOf: vertex.floatBuffer())
        }
        return vd
    }()

    lazy var vertexData: [Vertex] = {
        return createGrid(rows, columns, 0, 0, 1, 1)
    }()

    //tesselating a grid into triangle / line strip
    private func createGrid(_ rows: Int, _ columns: Int, _ r: Float, _ g: Float, _ b: Float, _ a: Float)
        -> [Vertex] {
            var res: [Vertex] = []

            let stepX: Float = Float(2.0 / Float(columns))
            let stepY: Float = Float(2.0 / Float(rows))

            var grid2D: [[Vertex?]] = Array(repeating: Array(repeating: nil, count: columns+1), count: rows+1)
            for iiY in 0..<rows+1 {
                for iiX in 0..<columns+1 {
                    grid2D[iiY][iiX] = Vertex(x: -1+Float(iiX)*stepX, y: -1+Float(iiY)*stepY, z: 0, r: r, g: g, b: b, a: a)
                }
            }
            for iiY in 0..<rows {
                for iiX in 0..<columns {
                    let topIdx = iiY
                    let bottomIdx = iiY+1
                    let leftIdx = iiX
                    let rightIdx = iiX+1

                    let a = grid2D[topIdx][leftIdx]!
                    let b = grid2D[bottomIdx][leftIdx]!
                    let c = grid2D[bottomIdx][rightIdx]!
                    let d = grid2D[topIdx][rightIdx]!

                    res.append(contentsOf: [a, b, b, c, c, d, d, a, a, c])
                    //res.append(contentsOf: [a,b,c, a,c,d]) // uncomment for triangles
                }
            }
      return res
    }
}
