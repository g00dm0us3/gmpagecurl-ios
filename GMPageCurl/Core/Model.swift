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

    let rows = 75
    let columns = 75

    lazy var serializedVertexData: [Float] = {
        var vd = [Float]()

        for vertex in vertexData {
            vd.append(contentsOf: vertex.floatBuffer())
        }
        return vd
    }()
    
    lazy var serializedVertexDataForCompute: [Float32] = {
        var vd = Array(repeating: Float32(1), count: rows*columns*4)//[Float32]()
        var res: [Vertex] = []

        let stepX: Float = Float(2.0 / Float(columns-1))
        let stepY: Float = Float(2.0 / Float(rows-1))

        var i = 0
        var grid2D: [[Vertex?]] = Array(repeating: Array(repeating: nil, count: columns+1), count: rows+1)
        for iiY in 0..<rows {
            for iiX in 0..<columns {
                //grid2D[iiY][iiX] = Vertex(x: -1+Float(iiX)*stepX, y: -1+Float(iiY)*stepY, z: 0, r: 0, g: 0, b: 0, a: 0)
                let x = -1+Float32(iiX)*stepX
                let y = -1+Float32(iiY)*stepY
                //vd.append(contentsOf: [x, y, 0, 1])
                vd[i] = x
                vd[i+1] = y
                vd[i+2] = 0
                vd[i+3] = 1
                i += 4
            }
        }

        return vd
    }()

    lazy var vertexData: [Vertex] = {
        return createGrid(rows, columns, 0, 0, 1, 1)
    }()
    
    var vertexIndicies:[Int32] = []
    
    func tupleToArray(tuple: (Int, Int)) -> [Int32] {
        return [Int32(tuple.0), Int32(tuple.1)]
    }

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

            for iiY in 0..<rows-1 {
                for iiX in 0..<columns-1 {
                    let topIdx = iiY
                    let bottomIdx = iiY+1
                    let leftIdx = iiX
                    let rightIdx = iiX+1

                    let a = grid2D[topIdx][leftIdx]!
                    let b = grid2D[bottomIdx][leftIdx]!
                    let c = grid2D[bottomIdx][rightIdx]!
                    let d = grid2D[topIdx][rightIdx]!

                    let aIdx = (topIdx, leftIdx)
                    let bIdx = (bottomIdx, leftIdx)
                    let cIdx = (bottomIdx, rightIdx)
                    let dIdx = (topIdx, rightIdx)
                    
                    res.append(contentsOf: [a, b, b, c, c, d, d, a, a, c])
                    
                    var idxArr = [Int32]()
                    
                    //idxArr.append(contentsOf: tupleToArray(tuple: aIdx))
                    //idxArr.append(contentsOf: tupleToArray(tuple: dIdx))
                    
                    //idxArr.append(contentsOf: tupleToArray(tuple: bIdx))
                    //idxArr.append(contentsOf: tupleToArray(tuple: dIdx))
                                    
                    
                    /*idxArr.append(contentsOf: tupleToArray(tuple: aIdx))
                    idxArr.append(contentsOf: tupleToArray(tuple: bIdx))
                    idxArr.append(contentsOf: tupleToArray(tuple: bIdx))
                    idxArr.append(contentsOf: tupleToArray(tuple: cIdx))
                    
                    idxArr.append(contentsOf: tupleToArray(tuple: cIdx))
                    idxArr.append(contentsOf: tupleToArray(tuple: dIdx))
                    idxArr.append(contentsOf: tupleToArray(tuple: dIdx))
                    idxArr.append(contentsOf: tupleToArray(tuple: aIdx))
                    
                    idxArr.append(contentsOf: tupleToArray(tuple: aIdx))
                    idxArr.append(contentsOf: tupleToArray(tuple: cIdx))*/
                    
                    idxArr.append(contentsOf: tupleToArray(tuple: aIdx));
                    idxArr.append(contentsOf: tupleToArray(tuple: bIdx));
                    idxArr.append(contentsOf: tupleToArray(tuple: cIdx));
                    idxArr.append(contentsOf: tupleToArray(tuple: aIdx));
                    idxArr.append(contentsOf: tupleToArray(tuple: cIdx));
                    idxArr.append(contentsOf: tupleToArray(tuple: dIdx));
                    
                    
                    vertexIndicies.append(contentsOf: idxArr)
                    //res.append(contentsOf: [a,b,c, a,c,d]) // uncomment for triangles
                }
            }

      return res
    }
}
