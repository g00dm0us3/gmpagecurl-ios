//
//  Model.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 3/16/19.
//  Copyright © 2019 g00dm0us3. All rights reserved.
//

import Foundation
import Metal
import GLKit

class Model: Equatable {
    
    //todo: doesn't work - comparison prevents update
    static func == (lhs: Model, rhs: Model) -> Bool {
        return lhs.guid == rhs.guid;
    }
    
    //change guid in each model mutating operation
    private var guid = UUID().uuidString
    
    var vertices: [Vertex]!
    
    private let rows = 20
    private let columns = 20//Int(ceil(210*(325.0/667)))
    
    private let pageWidth:Float = 2.0 // in normalized coords
    private let pageHeight: Float = 2.0 // in normalized coords
    
    var glkMatrix: GLKMatrix4
    var matrix4: GLKMatrix4
    
    private let screenWidth:Float = 325.0 // RenderingViewController width - height
    private let screenHeight:Float = 667.0
    
    var modelViewMatrix: GLKMatrix4 {
        get {
            return matrix4
        }
    }
    
    var normalMatrix: GLKMatrix3 {
        get {
            
            var res = GLKMatrix3Identity
            res.m00 = matrix4.m00
            res.m01 = matrix4.m01
            res.m02 = matrix4.m02
            
            res.m10 = matrix4.m10
            res.m11 = matrix4.m11
            res.m12 = matrix4.m12
            
            res.m20 = matrix4.m20
            res.m21 = matrix4.m21
            res.m22 = matrix4.m22
            
            
            
            
            
            return GLKMatrix3InvertAndTranspose(res, nil)
        }
    }
    
    var replaying: Bool = false
    
    var displacement: Float
    private(set) var phi: Float
    
    var lastTouch: CGPoint = CGPoint.zero
    var firstTouch: CGPoint = CGPoint.zero
    private var lastTranslation: CGPoint = CGPoint.zero
    
    var translation:CGPoint {
        set (newTranslation) {
            let vecX = Float(newTranslation.x - lastTouch.x)
            let vecY = Float(newTranslation.y - lastTouch.y)
            let filterFactor:Float = 0.98
            

            lastTouch = newTranslation
            
            let t = (screenWidth/2 - Float(firstTouch.x+newTranslation.x)) / screenWidth
            
            displacement =  -t

            var d = Float(displacement)
            var newPhi = (acos((abs(vecX))/(sqrt(vecX*vecX+vecY*vecY))))
            if case .minus = vecY.sign {newPhi *= -1 }
            
            //todo: filter phi signal for high frequencies
            if !newPhi.isNaN {
                //
                //newPhi = phi
                
            
                if newPhi > Float.pi/64 && newPhi <= Float.pi / 4 {
                    newPhi = Float.pi/8
                }
                if newPhi > Float.pi/4 && newPhi <= Float.pi/2 {
                    newPhi = 3*Float.pi/8
                }
                if newPhi > Float.pi/2 && newPhi <= Float.pi*3/4 {
                    newPhi = 4*Float.pi/8
                }
                if newPhi > Float.pi*3/4 && newPhi <= Float.pi {
                    newPhi = 5*Float.pi/8
                }
                newPhi = rescale(val: newPhi, ra: Float.pi/8, rb: 5*Float.pi/8, na: -Float.pi/4, nb: Float.pi/4)
                phi = filterFactor * phi + (1.0 - filterFactor) * newPhi
            }
            
        }
        get {
            return lastTranslation
        }
        
    }
    func rescale(val: Float, ra: Float, rb: Float, na: Float, nb:Float)->Float {
        return (val-ra)*(nb-na)/(rb-ra)+na;
    }
    func getDisplacement()->Float {
        if(displacement == 1 && replaying) {
            replaying = false
            lastTouch = CGPoint.zero
            firstTouch = CGPoint.zero
        }
        
        if(replaying) {
            displacement += 0.05
        }
        
        return displacement
    }
    
    private(set) var perspectiveMatrix: GLKMatrix4
    
    public var depthMVP: GLKMatrix4
    public var depthBiasMVP: GLKMatrix4;
    
    var vertexCount: Int {
        get {
            return vertices.count
        }
    }
    
    init() {
        glkMatrix = GLKMatrix4Identity
        
        displacement = 1
        phi = 0
        matrix4 = glkMatrix
        
        let aspectRatio:Float = 1//(Float(screenWidth / screenHeight))
        perspectiveMatrix = GLKMatrix4MakePerspective( GLKMathDegreesToRadians(90.0), aspectRatio, 0.1, 100)
        
        
        
        let orthoMatrix = perspectiveMatrix
        //0.23, 0.3, 3
        let depthViewMatrix = GLKMatrix4MakeLookAt(0, 0.0, 1, 0, 0.0, 0, 0, 1, 0)
        let depthModelMatrix = GLKMatrix4Scale(GLKMatrix4Identity, aspectRatio, 1, 1)
        
        
        
        //for shadow sampling
        let depthBiasMatrix = GLKMatrix4Identity;

        depthMVP = GLKMatrix4Multiply(GLKMatrix4Multiply(orthoMatrix, depthViewMatrix), depthModelMatrix)
        depthBiasMVP = GLKMatrix4Multiply(depthBiasMatrix, depthMVP);

        vertices = createGrid(rows, columns, 0.0, 0.0, 1.0, 1.0)
        
    
        var worldMatrix = GLKMatrix4Identity;
        
        // z = 1/(tan(fov/2))
        worldMatrix = GLKMatrix4Translate(worldMatrix, 0, 0, -1.1)
        worldMatrix = GLKMatrix4Scale(worldMatrix, aspectRatio, 1.0, 1.0)
        
        matrix4 = worldMatrix
    }
    
    func printM4(_ m: GLKMatrix4) {
        print("⎡\(m.m00) \(m.m01) \(m.m02) \(m.m03)⎤")
        print("⎢\(m.m10) \(m.m11) \(m.m12) \(m.m13)⎥")
        print("⎢\(m.m20) \(m.m21) \(m.m22) \(m.m23)⎥")
        print("⎣\(m.m30) \(m.m31) \(m.m32) \(m.m33)⎦")
    }
    
   func getVertexData()->[Float] {
        var vd = Array<Float>()
        
        for vertex in vertices {
            vd.append(contentsOf: vertex.floatBuffer())
        }
        
        return vd
    }
    
    //tesselating a grid into triangle strip
    private func createGrid(_ rows: Int, _ columns: Int, _ r: Float, _ g: Float, _ b:Float, _ a: Float)
        ->[Vertex] {
            var res: [Vertex] = []
            
            let stepX: Float = Float(pageWidth / Float(columns))
            let stepY: Float = Float(pageHeight / Float(rows))
            
            var grid2D: [[Vertex?]] = Array(repeating: Array(repeating: nil, count: columns+1), count: rows+1)
            for iiY in 0..<rows+1
            {
                for iiX in 0..<columns+1
                {
                    grid2D[iiY][iiX] = Vertex(x: -1+Float(iiX)*stepX, y: -1+Float(iiY)*stepY, z: 0,  r:  r, g:  g, b:  b, a:  a)
                }
            }
            for iiY in 0..<rows
            {
                for iiX in 0..<columns
                {
                    let topIdx = iiY
                    let bottomIdx = iiY+1
                    let leftIdx = iiX
                    let rightIdx = iiX+1
                    
                    let a = grid2D[topIdx][leftIdx]!
                    let b = grid2D[bottomIdx][leftIdx]!
                    let c = grid2D[bottomIdx][rightIdx]!
                    let d = grid2D[topIdx][rightIdx]!
                    
                    res.append(contentsOf: [a,b, b,c, c,d, d,a, a,c])
                    //res.append(contentsOf: [a,b,c, a,c,d])
                }
            }
      return res
    }
}
