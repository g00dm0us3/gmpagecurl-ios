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
    
    private var currentDrawable: CAMetalDrawable?
    private var renderingPipeline: RenderingPipeline
    private var model: Model
    
    init() {
        model = Model()
        
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

    func render() {
        fillBuffers()
        
        let commandBuffer = renderingPipeline.getCommandBuffer()
        
        let drawable = getCurrentDrawable()
        let primitiveType = MTLPrimitiveType.line
        
        let renderPassDescriptor = renderingPipeline.renderPassDescriptorForTexture(texture: drawable?.texture)
        
        renderPassDescriptor.colorAttachments[0].texture = drawable?.texture
        //renderPassDescriptor.depthAttachment = nil
        var renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.pushDebugGroup("COLOR")
        renderEncoder.label = "CL"
        
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setCullMode(MTLCullMode.none)
        
        renderEncoder.setRenderPipelineState(renderingPipeline.colorPipelineState!)
        
        //renderEncoder.setDepthStencilState(renderingPipeline.depthStencilState!)
        
        //renderEncoder.setFragmentTexture(renderingPipeline.shadowTexture!, index: 0)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(inputBuffer, offset: 0, index: 2)
        //renderEncoder.setFragmentTexture(texture, index: 1)

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
    
    private func fillBuffers(){
        makeBuffers()
        
        guard let uniformBufferPointer = uniformBuffer?.contents() else { fatalError("Couldn't access buffer") }
        
        var modelMatrix = MatrixUtils.glk4x4tosimd(mat: model.modelViewMatrix)
        var perspectiveMatrix = MatrixUtils.glk4x4tosimd(mat: model.perspectiveMatrix)
        
        memcpy(uniformBufferPointer, &modelMatrix, MatrixUtils.matrix4x4Size)
        memcpy(uniformBufferPointer + MatrixUtils.matrix4x4Size, &perspectiveMatrix, MatrixUtils.matrix4x4Size)
        
        guard let inputBuifferPointer = inputBuffer?.contents() else { fatalError("Couldn't access buffer") }
        
        var displ = model.getDisplacement()
        
        displ = 0.4; /// - TODO: convert to metal coordinate system.
        var phi = degree2rad(degree: 42)

        memcpy(inputBuifferPointer, &displ, MemoryLayout<Float>.size)
        memcpy(inputBuifferPointer + MemoryLayout<Float>.size, &phi, MemoryLayout<Float>.size)
    }
    
    private func makeBuffers() {
        
        let device = RenderingDevice.defaultDevice
        
        if uniformBuffer == nil {
            let totalSz = 2*MatrixUtils.matrix4x4Size;
            
            guard let buffer = device.makeBuffer(length: totalSz, options: []) else { fatalError("Couldn't create a uniform buffer") }
            
            uniformBuffer = buffer
        }
        
        if inputBuffer == nil {
            guard let buffer = device.makeBuffer(length: 2*MemoryLayout<Float>.size, options: []) else { fatalError("Couldn't create input buffer") }
            
            inputBuffer = buffer
        }
        
        if vertexBuffer == nil {
            
            let vertexData = model.getVertexData()
            let dataSize = vertexData.count * MemoryLayout<Float>.size
            
            guard let buffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: []) else { fatalError("Couldn't create vertex buffer") }
            vertexBuffer = buffer
        }
    }
    
    func degree2rad(degree: Float) -> Float
    {
        return (degree*Float.pi)/180.0
    }
    
}
