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

// - TODO: cleanup code.

final class Renderer {
    private var vertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?
    private var inputBuffer: MTLBuffer?
    private var vertexIndexBuffer: MTLBuffer?

    private var currentDrawable: CAMetalDrawable?
    private var renderingPipeline: RenderingPipeline
    private var model: Model

    private var perspectiveMatrix: simd_float4x4
    private var lightMatrix: simd_float4x4
    private let inputTexture:MTLTexture
    private let computedPositions:MTLTexture // positions textures
    private let computedNormals: MTLTexture
    private var depthTexture: MTLTexture!
    
    private var inputManager: InputManager
    
    private var worldMatrix: simd_float4x4 {
        return inputManager.worldMatrix
    }
    
    private var lightModelMatrix: simd_float3x3 {
        let lightModelMatrix = simd_float3x3([
            simd_float3(worldMatrix[0][0],worldMatrix[0][1],worldMatrix[0][2]),
            simd_float3(worldMatrix[1][0],worldMatrix[1][1],worldMatrix[1][2]),
            simd_float3(worldMatrix[2][0],worldMatrix[2][1],worldMatrix[2][2])]).inverse;
        return lightModelMatrix.transpose
    }
    
    init(inputManager: InputManager) {
        self.inputManager = inputManager
        model = Model()
        renderingPipeline = RenderingPipeline()

        perspectiveMatrix = MatrixUtils.matrix_perspective(aspect: 1, fovy: 90.0, near: 0.1, far: 100)
        
        
        let ortho = MatrixUtils.matrix_ortho(left: -1, right: 1, bottom: -1, top: 1, near: 1, far: -1)
        let lightView = MatrixUtils.matrix_lookat(at: simd_float3(0,0,0), eye: simd_float3(0,0,-1), up: simd_float3(0,1,0))
        lightMatrix = ortho * lightView
        
        inputTexture = renderingPipeline.makeInputComputeTexture(pixelFormat: .rgba32Float, width: model.columns, height: model.rows)
        
        var kernelData = model.serializedVertexDataForCompute
        
        inputTexture.replace(region: MTLRegionMake2D(0, 0, model.columns, model.rows), mipmapLevel: 0, withBytes: &kernelData, bytesPerRow: 4*MemoryLayout<Float32>.size*model.columns)
        
        computedNormals = renderingPipeline.makeOutputComputeTexture(pixelFormat: .rgba32Float, width: model.columns, height: model.rows)
        computedPositions = renderingPipeline.makeOutputComputeTexture(pixelFormat: .rgba32Float, width: model.columns, height: model.rows)
    }
    
    func setInputManager(_ inputManager: InputManager) {
        self.inputManager = inputManager
    }
    
    func render(in layer: CAMetalLayer) {
        fillBuffers()

        let commandBuffer = renderingPipeline.getCommandBuffer()

        let drawable = self.drawable(from: layer)
        
        computePositionsPass(commandBuffer)
        shadowRenderPass(commandBuffer, (drawable.texture.width, drawable.texture.height))
        colorRenderPass(commandBuffer, drawable)

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func computePositionsPass(_ commandBuffer: MTLCommandBuffer) {
        let computePositionsPassEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        computePositionsPassEncoder.pushDebugGroup("COMPUTE POSITIONS")
        let computePositionsPipelineState = renderingPipeline.createKernelPipelineState("compute_positions")

        computePositionsPassEncoder.setComputePipelineState(computePositionsPipelineState)
        computePositionsPassEncoder.setTexture(inputTexture, index: 0)
        computePositionsPassEncoder.setTexture(computedPositions, index: 1)
        computePositionsPassEncoder.setBuffer(inputBuffer, offset: 0, index: 0)

        let w = computePositionsPipelineState.threadExecutionWidth
        let h = computePositionsPipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        
        let threadgroupsPerGrid = MTLSize(width: (model.columns + w - 1) / w,
                                                  height: (model.rows + h - 1) / h,
                                                  depth: 1)
        
        computePositionsPassEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        let computeNormalsPipelineState = renderingPipeline.createKernelPipelineState("compute_normals")
        computePositionsPassEncoder.setComputePipelineState(computeNormalsPipelineState)
        computePositionsPassEncoder.setTexture(computedPositions, index: 0)
        computePositionsPassEncoder.setTexture(computedNormals, index: 1)
        
        computePositionsPassEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        computePositionsPassEncoder.endEncoding()
        computePositionsPassEncoder.popDebugGroup()
    }
    
    private func shadowRenderPass(_ commandBuffer: MTLCommandBuffer, _ size: (width: Int, height: Int)) {
        // MARK: Depth Texture
        /*let msTextureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: size.width, height: size.height, mipmapped: false)
        msTextureDesc.storageMode = .private
        msTextureDesc.mipmapLevelCount = 1
        msTextureDesc.textureType = .type2DMultisample
        msTextureDesc.sampleCount = 4
        msTextureDesc.usage = [.renderTarget]
        let msTexture = RenderingDevice.defaultDevice.makeTexture(descriptor: msTextureDesc)*/
        
        // MARK: Setup Render Pass Descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        
        let depthAttachemntDescriptor = MTLRenderPassDepthAttachmentDescriptor()
        
        let regularTextureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: size.width, height: size.height, mipmapped: false)
        regularTextureDesc.storageMode = .private
        regularTextureDesc.mipmapLevelCount = 1
        regularTextureDesc.textureType = .type2D
        regularTextureDesc.usage = [.shaderRead, .renderTarget]
        depthTexture = RenderingDevice.defaultDevice.makeTexture(descriptor: regularTextureDesc)
        
        //depthAttachemntDescriptor.resolveTexture = depthTexture
        //depthAttachemntDescriptor.texture = msTexture
        depthAttachemntDescriptor.texture = depthTexture
        depthAttachemntDescriptor.loadAction = .clear
        //depthAttachemntDescriptor.storeAction = .multisampleResolve // not available in simulator
        depthAttachemntDescriptor.storeAction = .store
        depthAttachemntDescriptor.clearDepth = 1
        
        renderPassDescriptor.depthAttachment = depthAttachemntDescriptor
        
        // MARK: Setup Render Pipeline State
        let shadowPipelineState = try! renderingPipeline.makeShadowPipelineState()
        
        // MARK: Configure Depth on render pass
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        guard let depthState = RenderingDevice.defaultDevice.makeDepthStencilState(descriptor: depthDescriptor) else { fatalError("Cannot make depth texture, yo") }
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.pushDebugGroup("SHADOW")
        
        // cull & front facing
        renderEncoder.setRenderPipelineState(shadowPipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(vertexIndexBuffer, offset: 0, index: 1)
        
        renderEncoder.setVertexTexture(computedPositions, index: 0)
        renderEncoder.setVertexTexture(computedNormals, index: 1) // computed vertices / normals

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: model.vertexIndicies.count/2)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }
    
    private func colorRenderPass(_ commandBuffer: MTLCommandBuffer, _ drawable: CAMetalDrawable) {
        // MARK: Start Color Pass
        let renderPassDescriptor = MTLRenderPassDescriptor() // a group of rendering targets
        
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.multisampleResolve
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: drawable.texture.width, height: drawable.texture.height, mipmapped: false)
        textureDescriptor.textureType = .type2DMultisample
        textureDescriptor.sampleCount = 4
        textureDescriptor.storageMode = .memoryless
        textureDescriptor.usage = .renderTarget
        let msTexture = RenderingDevice.defaultDevice.makeTexture(descriptor: textureDescriptor)
        
        renderPassDescriptor.colorAttachments[0].texture = msTexture
        renderPassDescriptor.colorAttachments[0].resolveTexture = drawable.texture
        //renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderEncoder.pushDebugGroup("COLOR")
        renderEncoder.label = "CL"
        
        renderEncoder.setRenderPipelineState(renderingPipeline.colorPipelineState!) // - TODO: what in the actual fuck?!
        
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(vertexIndexBuffer, offset: 0, index: 1)
        
        renderEncoder.setVertexTexture(computedPositions, index: 0)
        renderEncoder.setVertexTexture(computedNormals, index: 1) // computed vertices / normals
        
        renderEncoder.setFragmentTexture(depthTexture, index: 0)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: model.vertexIndicies.count/2)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
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

        var worldMatrix = self.worldMatrix
        var lightModelMatrix = self.lightModelMatrix

        memcpy(uniformBufferPointer, &lightMatrix, MatrixUtils.matrix4x4Size)
        memcpy(uniformBufferPointer + MatrixUtils.matrix4x4Size, &worldMatrix, MatrixUtils.matrix4x4Size)
        memcpy(uniformBufferPointer + 2*MatrixUtils.matrix4x4Size, &perspectiveMatrix, MatrixUtils.matrix4x4Size)
        memcpy(uniformBufferPointer + 3*MatrixUtils.matrix4x4Size, &lightModelMatrix, MatrixUtils.matrix4x4Size)

        guard let inputBuifferPointer = inputBuffer?.contents() else { fatalError("Couldn't access buffer") }

        var radius = inputManager.radius
        var phi = inputManager.phi
        var viewState = inputManager.renderingViewState.rawValue

        memcpy(inputBuifferPointer, &radius, MemoryLayout<Float>.size)
        memcpy(inputBuifferPointer + MemoryLayout<Float>.size, &phi, MemoryLayout<Float>.size)
        memcpy(inputBuifferPointer + 2*MemoryLayout<Float>.size, &viewState, MemoryLayout<Int>.size)
    }

    private func makeBuffers() {

        let device = RenderingDevice.defaultDevice

        if uniformBuffer == nil {
            let totalSz = 4*MatrixUtils.matrix4x4Size

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
        
        if vertexIndexBuffer == nil {
            let vertexIndicies = model.vertexIndicies
            let dataSize = vertexIndicies.count * MemoryLayout<Int32>.size
            
            guard let buffer = device.makeBuffer(bytes: vertexIndicies, length: dataSize, options: []) else { fatalError("Couldn't create vertex index buffer") }
            
            vertexIndexBuffer = buffer
        }
    }
}
