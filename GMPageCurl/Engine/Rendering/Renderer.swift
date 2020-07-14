//
//  Renderer.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 3/16/19.
//  Copyright © 2019 g00dm0us3. All rights reserved.
//

import Foundation
import UIKit
import Metal
import GLKit
import CoreGraphics

class Renderer {
    private(set) var metalLayer: CAMetalLayer!
    private var vertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?
    private var inputBuffer: MTLBuffer?
    private var lightUniformBuffer: MTLBuffer?
    private var model: Model?
    
    private var  currentDrawable: CAMetalDrawable?
    private var renderingPipeline: RenderingPipeline
    
    init() {
        
        let device = RenderingDevice.shared.device!
        
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = MTLPixelFormat.bgra8Unorm
        
        renderingPipeline = RenderingPipeline()
        
        texture = createTexture()
    }
    
    public func setMetalLayerFrame(frame: CGRect) {
        metalLayer.frame = frame
    }
    
    public func resetCurrentDrawable() {
        currentDrawable = nil;
    }

    func render(model: Model) {
        makeBuffers(model: model)
        
        let commandBuffer = renderingPipeline.getCommandBuffer()
        
        let drawable = getCurrentDrawable()
        //shadow pass
        var renderPassDescriptor = renderingPipeline.shadowRenderPassDescriptor!
        var renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        let primitiveType = MTLPrimitiveType.line
        
        renderEncoder.pushDebugGroup("SHADOW")
        renderEncoder.label = "SH"
        
        renderEncoder.setCullMode(.none)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        renderEncoder.setRenderPipelineState(renderingPipeline.shadowPipelineState!)
        renderEncoder.setDepthStencilState(renderingPipeline.shadowDepthStencilState!)
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(lightUniformBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(inputBuffer, offset: 0, index: 2)
        
        renderEncoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: model.vertexCount)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        //color pass
        renderEncoder.pushDebugGroup("COLOR")
        renderEncoder.label = "CL"
        
        renderPassDescriptor = renderingPipeline.renderPassDescriptorForTexture(texture: drawable?.texture)
    
        renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setCullMode(MTLCullMode.none)
        
        renderEncoder.setRenderPipelineState(renderingPipeline.colorPipelineState!)
        
        renderEncoder.setDepthStencilState(renderingPipeline.depthStencilState!)
        
        renderEncoder.setFragmentTexture(renderingPipeline.shadowTexture!, index: 0)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(inputBuffer, offset: 0, index: 2)
        renderEncoder.setFragmentTexture(texture, index: 1)

        //set vertex buffer for matrix
        renderEncoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: model.vertexCount)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable!)
        commandBuffer.commit()
    }
    
    private func getCurrentDrawable() -> CAMetalDrawable! {
        //drawable can be nil if offscreen
        //or if taken too long to render
        //drawable is returned from command buffer
        
        while(currentDrawable == nil) {
            currentDrawable = metalLayer.nextDrawable()
        }
        
        return currentDrawable!
        
    }
    
    var texture: MTLTexture!
    var target: MTLTextureType!
    var width: Int!
    var height: Int!
    var depth: Int!
    var format: MTLPixelFormat!
    var hasAlpha: Bool!
    var path: String!
    var isMipmaped: Bool!
    let bytesPerPixel:Int! = 4
    let bitsPerComponent:Int! = 8
    
    private func createTexture() -> MTLTexture {
        let device = RenderingDevice.shared.device!
        let image = (UIImage(named: "TextImage")?.cgImage)!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let width = image.width
        let height = image.height
        
        let rowBytes = width * bytesPerPixel
        
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: rowBytes, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let bounds = CGRect(x: 0, y: 0, width: Int(width), height: Int(height))
        context.clear(bounds)
        
        /*if flip == false{
            context.translateBy(x: 0, y: CGFloat(self.height))
            context.scaleBy(x: 1.0, y: -1.0)
        }*/
        
        context.draw(image, in: bounds)
        isMipmaped = false
        
        let texDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.rgba8Unorm, width: Int(width), height: Int(height), mipmapped: isMipmaped)
        target = texDescriptor.textureType
        texture = device.makeTexture(descriptor: texDescriptor)
        
        let pixelsData = context.data!
        let region = MTLRegionMake2D(0, 0, Int(width), Int(height))
        texture.replace(region: region, mipmapLevel: 0, withBytes: pixelsData, bytesPerRow: Int(rowBytes))
        
        return texture
    }
    
    private func makeBuffers(model: Model){
        //todo: this function is the reason for high CPU utilization (a lot of copying)
       /* if(self.model != nil && (self.model! == model)) {
            return;
        }*/
        
        let device = RenderingDevice.shared.device!
        self.model = model
        
        if(uniformBuffer == nil) {
            var modelMatrix = MatrixUtils.glk4x4tosimd(mat: model.modelViewMatrix)
            var perspectiveMatrix = MatrixUtils.glk4x4tosimd(mat: model.perspectiveMatrix)
            var normalMatrix = MatrixUtils.glk3x3tosimd(mat: model.normalMatrix)
            var depthBiasMVP = MatrixUtils.glk4x4tosimd(mat: model.depthBiasMVP)
            
            let matrixSz4x4 = MemoryLayout<simd_float4x4>.size;
            let matrixSz3x3 = MemoryLayout<simd_float3x3>.size;
            let totalSz = matrixSz4x4*3+matrixSz3x3;
            
            uniformBuffer = device.makeBuffer(length: totalSz, options: []) //copying all the vars here
            var bufferPointer = uniformBuffer?.contents()
   
            memcpy(bufferPointer, &modelMatrix, matrixSz4x4)
  
            memcpy(bufferPointer!+matrixSz4x4, &perspectiveMatrix, matrixSz4x4)

            memcpy(bufferPointer!+2*matrixSz4x4, &depthBiasMVP, matrixSz4x4)

            memcpy(bufferPointer!+3*matrixSz4x4, &normalMatrix, matrixSz3x3)
            
            var depthMVP = MatrixUtils.glk4x4tosimd(mat:model.depthMVP)
            
            lightUniformBuffer = device.makeBuffer(length: matrixSz4x4, options: []) //copying all the vars here
            bufferPointer = lightUniformBuffer?.contents()
            
            memcpy(bufferPointer, &depthMVP, matrixSz4x4)
        }
        
        if inputBuffer == nil {
            inputBuffer = device.makeBuffer(length: 2*MemoryLayout<Float>.size, options: [])
        }
        let bufferPointer1 = inputBuffer?.contents()
        
        var displ = model.getDisplacement()
        
        var phi = Float.pi/4
        //var phi = model.phi

        memcpy(bufferPointer1, &displ, MemoryLayout<Float>.size)
        memcpy(bufferPointer1!+MemoryLayout<Float>.size, &phi, MemoryLayout<Float>.size)
        
        if(vertexBuffer == nil) {
            //todo: apply shared buffer trick from Apple tutorial - Managing Large Vertex Buffer in Metal Bookmarks
            let vertexData = self.model!.getVertexData()
        
            let dataSize = vertexData.count * MemoryLayout<Float>.size //todo: what the difference from stride? test in plaground
        
            vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
        }
    }
    
}
