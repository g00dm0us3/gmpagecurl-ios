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
    private var vertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?
    private var inputBuffer: MTLBuffer?
    
    private var currentDrawable: CAMetalDrawable?
    private var renderingPipeline: RenderingPipeline
    private var model: Model
    
    init() {
        model = Model()
        renderingPipeline = RenderingPipeline()
    }

    func render(in layer: CAMetalLayer) {
        
        fillBuffers()
        
        let commandBuffer = renderingPipeline.getCommandBuffer()
        
        let drawable = self.drawable(from: layer)
        let primitiveType = MTLPrimitiveType.line
        
        let renderPassDescriptor = renderingPipeline.renderPassDescriptor()
        
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.pushDebugGroup("COLOR")
        renderEncoder.label = "CL"
        
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setCullMode(MTLCullMode.none)
        
        renderEncoder.setRenderPipelineState(renderingPipeline.colorPipelineState!)

        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(inputBuffer, offset: 0, index: 2)

        //set vertex buffer for matrix
        renderEncoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: model.vertexCount)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func drawable(from layer: CAMetalLayer) -> CAMetalDrawable {
        //drawable can be nil if offscreen
        //or if taken too long to render
        //drawable is returned from command buffer
        
        currentDrawable = nil
        while(currentDrawable == nil) {
            currentDrawable = layer.nextDrawable()
        }
        
        return currentDrawable!
    }
    
    private func fillBuffers() {
        makeBuffers()
        
        guard let uniformBufferPointer = uniformBuffer?.contents() else { fatalError("Couldn't access buffer") }
        
        var modelMatrix = model.modelViewMatrix
        var perspectiveMatrix = model.perspectiveMatrix
        
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
