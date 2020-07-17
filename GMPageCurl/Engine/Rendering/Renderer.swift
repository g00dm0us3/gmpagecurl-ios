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
import simd
import CoreGraphics

final class Renderer {
    private var vertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?
    private var inputBuffer: MTLBuffer?

    private var currentDrawable: CAMetalDrawable?
    private var renderingPipeline: RenderingPipeline
    private var model: Model

    private(set) var perspectiveMatrix: simd_float4x4

    init() {
        model = Model()
        renderingPipeline = RenderingPipeline()

        perspectiveMatrix = MatrixUtils.matrix_perspective(aspect: 1, fovy: 90.0, near: 0.1, far: 100)
    }

    func render(in layer: CAMetalLayer) {

        fillBuffers()

        let commandBuffer = renderingPipeline.getCommandBuffer()

        let computePositionsPassEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        computePositionsPassEncoder.pushDebugGroup("COMPUTE POSITIONS")
        let computePositionsPipelineState = renderingPipeline.createKernelPipelineState("compute_positions")
        
        let inputTexture = renderingPipeline.makeInputComputeTexture(pixelFormat: .rgba32Float, width: model.columns, height: model.rows)
        // fill input texture
        
        var kernelData = model.serializedVertexDataForCompute
        
        inputTexture.replace(region: MTLRegionMake2D(0, 0, model.columns, model.rows), mipmapLevel: 0, withBytes: &kernelData, bytesPerRow: model.columns*32*4)
        
        var texData = Array(repeating: Float(0), count: kernelData.count)
        
        
        
        let outputTexture = renderingPipeline.makeOutputComputeTexture(pixelFormat: .rgba32Float, width: model.columns, height: model.rows)
        
        computePositionsPassEncoder.setComputePipelineState(computePositionsPipelineState)
        computePositionsPassEncoder.setTexture(inputTexture, index: 0)
        computePositionsPassEncoder.setTexture(outputTexture, index: 1)
        computePositionsPassEncoder.setBuffer(inputBuffer, offset: 0, index: 0)

        let w = computePositionsPipelineState.threadExecutionWidth
        let h = computePositionsPipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        
        let threadgroupsPerGrid = MTLSize(width: (model.columns + w - 1) / w,
                                                  height: (model.rows + h - 1) / h,
                                                  depth: 1)
        
        computePositionsPassEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        computePositionsPassEncoder.endEncoding()
        computePositionsPassEncoder.popDebugGroup()

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
        renderEncoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: model.vertexData.count)
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

        var worldMatrix = InputManager.defaultManager.worldMatrix

        memcpy(uniformBufferPointer, &worldMatrix, MatrixUtils.matrix4x4Size)
        memcpy(uniformBufferPointer + MatrixUtils.matrix4x4Size, &perspectiveMatrix, MatrixUtils.matrix4x4Size)

        guard let inputBuifferPointer = inputBuffer?.contents() else { fatalError("Couldn't access buffer") }

        var displacement = InputManager.defaultManager.displacement
        var phi = InputManager.defaultManager.phi
        var viewState = InputManager.defaultManager.viewState

        memcpy(inputBuifferPointer, &displacement, MemoryLayout<Float>.size)
        memcpy(inputBuifferPointer + MemoryLayout<Float>.size, &phi, MemoryLayout<Float>.size)
        memcpy(inputBuifferPointer + 2*MemoryLayout<Float>.size, &viewState, MemoryLayout<Int>.size)
    }

    private func makeBuffers() {

        let device = RenderingDevice.defaultDevice

        if uniformBuffer == nil {
            let totalSz = 2*MatrixUtils.matrix4x4Size

            guard let buffer = device.makeBuffer(length: totalSz, options: []) else { fatalError("Couldn't create a uniform buffer") }

            uniformBuffer = buffer
        }

        if inputBuffer == nil {
            guard let buffer = device.makeBuffer(length: 2*MemoryLayout<Float>.size+MemoryLayout<Int>.size, options: []) else { fatalError("Couldn't create input buffer") }

            inputBuffer = buffer
        }

        if vertexBuffer == nil {

            let vertexData = model.serializedVertexData
            let dataSize = vertexData.count * MemoryLayout<Float>.size

            guard let buffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: []) else { fatalError("Couldn't create vertex buffer") }
            vertexBuffer = buffer
        }
    }
}
