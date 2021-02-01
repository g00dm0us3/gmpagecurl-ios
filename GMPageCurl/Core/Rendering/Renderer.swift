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
    private var uniformBuffer: MTLBuffer?
    private var constantUniformBuffer: MTLBuffer?
    private var inputBuffer: MTLBuffer?
    private var vertexIndexBuffer: MTLBuffer?

    private var currentDrawable: CAMetalDrawable?

    fileprivate var vertexIndicies: [Int32] = []

    // should correspond to the #defines in shader
    fileprivate let modelWidth = 105
    fileprivate let modelHeight = 210

    private var defaultLibrary: MTLLibrary!

    private var device: MTLDevice {
        return DeviceWrapper.device
    }

    private let state: RendererState
    private let worldState: WorldState

    private var computedNormals: MTLTexture {
        return state.computedNormals!
    }

    private var computedPositions: MTLTexture {
        return state.computedPositions!
    }

    var cadDisplayLink: CADisplayLink!
    weak var renderingView: UIView?
    weak var underlyingView: UIView?

    var superPhi: Float = 0
    var superRadius: Float = 0

    private var isRunningPlayBack = false

    init(_ view: UIView, underlyingView: UIView) {
        state = RendererState(DeviceWrapper.device, modelWidth: modelWidth, modelHeight: modelHeight)
        worldState = WorldState()
        renderingView = view
        defaultLibrary = device.makeDefaultLibrary()
        self.underlyingView = underlyingView

        cadDisplayLink = CADisplayLink(target: self, selector: #selector(redraw))
        cadDisplayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
    }

    func setScale(_ scale: Float) {

    }

    func setPan(_ transition: CGPoint, velocity: CGPoint) {

    }

    func viewDidUpdate() {

    }

    func runPlayBack() {
        isRunningPlayBack = true
    }

    func stopPlayBack() {
        isRunningPlayBack = false
    }

    @objc
    private func redraw() {
        guard let mtlLayer = renderingView?.layer as? CAMetalLayer else { fatalError("This should be rendering layer!") }
        render(in: mtlLayer)
    }

    private func render(in layer: CAMetalLayer) {
        //guard worldState.stateUpdated else { return }
        defer {
            worldState.setStateProcessed()
            //cadDisplayLink.isPaused = true
            //underlyingView?.setNeedsDisplay()
        }

        let playBackStep = Float(0.09)
        if isRunningPlayBack {
            if superRadius - playBackStep <= 0 {
                superRadius = 0
                superPhi = 0
                isRunningPlayBack = false
            } else {
                superRadius -= playBackStep
            }
        }

        fillBuffers()

        let drawable = self.drawable(from: layer)

        let newCommandBuffer = state.buildTransientState(for: drawable)

        computePositionsPass(newCommandBuffer)
        shadowRenderPass(newCommandBuffer, (drawable.texture.width, drawable.texture.height))
        colorRenderPass(newCommandBuffer, drawable)

        newCommandBuffer.present(drawable)
        newCommandBuffer.commit()
    }

    private func computePositionsPass(_ commandBuffer: MTLCommandBuffer) {
        let computePositionsPassEncoder = commandBuffer.makeComputeCommandEncoder()!

        computePositionsPassEncoder.pushDebugGroup("COMPUTE POSITIONS")
        let computePositionsPipelineState = state.computePositionsPipelineState!
        let computeNormalsPipelineState = state.computeNormalsPipelineState!

        computePositionsPassEncoder.setComputePipelineState(computePositionsPipelineState)
        computePositionsPassEncoder.setTexture(computedPositions, index: 0)
        computePositionsPassEncoder.setBuffer(inputBuffer, offset: 0, index: 0)

        let w = computePositionsPipelineState.threadExecutionWidth
        let h = computePositionsPipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)

        let threadgroupsPerGrid = MTLSize(width: (modelWidth + w - 1) / w,
                                                  height: (modelHeight + h - 1) / h,
                                                  depth: 1)

        computePositionsPassEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

        computePositionsPassEncoder.setComputePipelineState(computeNormalsPipelineState)
        computePositionsPassEncoder.setTexture(computedNormals, index: 1)

        computePositionsPassEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

        computePositionsPassEncoder.endEncoding()
        computePositionsPassEncoder.popDebugGroup()
    }

    /// - TODO: create all the shit we need before launching first pass. this will get rid of EXC_BAD_ACCESS here and there
    private func shadowRenderPass(_ commandBuffer: MTLCommandBuffer, _ size: (width: Int, height: Int)) {
        // MARK: Setup Render Pass Descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.depthAttachment = state.depthAttachemntDescriptorForShadowPass!

        // MARK: Setup Render Pipeline State
        let shadowPipelineState = state.shadowPipelineState!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.pushDebugGroup("SHADOW")

        // cull & front facing
        renderEncoder.setRenderPipelineState(shadowPipelineState)
        renderEncoder.setDepthStencilState(state.depthStencilStateForShadowPass!)

        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(vertexIndexBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(constantUniformBuffer, offset: 0, index: 2)

        renderEncoder.setVertexTexture(computedPositions, index: 0)
        renderEncoder.setVertexTexture(computedNormals, index: 1) // computed vertices / normals

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexIndicies.count/2)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }

    private func colorRenderPass(_ commandBuffer: MTLCommandBuffer, _ drawable: CAMetalDrawable) {
        // MARK: Start Color Pass

        /*let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: drawable.texture.width, height: drawable.texture.height, mipmapped: false)
        textureDescriptor.textureType = .type2DMultisample
        textureDescriptor.sampleCount = 4
        textureDescriptor.storageMode = .memoryless
        textureDescriptor.usage = .renderTarget*/
        // add code detecting when we are in simulator. depth testing w. MSAA is not supported in simulator.
        //let msTexture = RenderingDevice.defaultDevice.makeTexture(descriptor: textureDescriptor)
        let renderPassDescriptor = MTLRenderPassDescriptor() // a group of rendering targets
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0) // do not touch! the only way to make it transparent in simulator
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        //renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.multisampleResolve
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.depthAttachment = state.depthAttachmentDescriptorForColorPass!

        //renderPassDescriptor.colorAttachments[0].texture = msTexture
        //renderPassDescriptor.colorAttachments[0].resolveTexture = drawable.texture
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture

        let colorPipelineState = state.colorPipelineState!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!

        renderEncoder.pushDebugGroup("COLOR")
        renderEncoder.label = "CL"

        renderEncoder.setDepthStencilState(state.depthStencilStateForColorPass!)
        renderEncoder.setRenderPipelineState(colorPipelineState)

        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(vertexIndexBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(constantUniformBuffer, offset: 0, index: 2)

        renderEncoder.setVertexTexture(computedPositions, index: 0)
        renderEncoder.setVertexTexture(computedNormals, index: 1) // computed vertices / normals

        renderEncoder.setFragmentTexture(state.depthTexture!, index: 0)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexIndicies.count / 2)
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

        var worldMatrix = self.worldState.worldMatrix
        var lightModelMatrix = self.worldState.lightModelMatrix

        memcpy(uniformBufferPointer, &worldMatrix, MatrixUtils.matrix4x4Size)
        memcpy(uniformBufferPointer + MatrixUtils.matrix4x4Size, &lightModelMatrix, MatrixUtils.matrix4x4Size)

        guard let inputBuifferPointer = inputBuffer?.contents() else { fatalError("Couldn't access buffer") }

        var radius = superRadius//worldState.distance
        var phi = superPhi//worldState.phi
        var viewState = 0 // 1 will produce a box view, not very useful, only when debugging geometry

        memcpy(inputBuifferPointer, &radius, MemoryLayout<Float>.size)
        memcpy(inputBuifferPointer + MemoryLayout<Float>.size, &phi, MemoryLayout<Float>.size)
        memcpy(inputBuifferPointer + 2*MemoryLayout<Float>.size, &viewState, MemoryLayout<Int>.size)
    }

    private func makeBuffers() {
        if uniformBuffer == nil {
            let totalSz = 2*MatrixUtils.matrix4x4Size

            guard let buffer = device.makeBuffer(length: totalSz, options: []) else { fatalError("Couldn't create a uniform buffer") }

            uniformBuffer = buffer
        }

        if constantUniformBuffer == nil {
            let totalSz = 2*MatrixUtils.matrix4x4Size

            guard let buffer = device.makeBuffer(length: totalSz, options: []) else { fatalError("Couldn't create a uniform buffer") }

            constantUniformBuffer = buffer
            var lightMatrix = worldState.lightMatrix
            var perspectiveMatrix = worldState.perspectiveMatrix

            guard let uniformBufferPointer = constantUniformBuffer?.contents() else { fatalError("Couldn't access buffer") }

            memcpy(uniformBufferPointer, &lightMatrix, MatrixUtils.matrix4x4Size)
            memcpy(uniformBufferPointer + MatrixUtils.matrix4x4Size, &perspectiveMatrix, MatrixUtils.matrix4x4Size)
        }

        if inputBuffer == nil {
            guard let buffer = device.makeBuffer(length: 2*MemoryLayout<Float>.size+MemoryLayout<Int>.size, options: []) else { fatalError("Couldn't create input buffer") }
            inputBuffer = buffer
        }

        if vertexIndexBuffer == nil {
            computeVertexIndicies()
            let dataSize = vertexIndicies.count * MemoryLayout<Int32>.size

            guard let buffer = device.makeBuffer(bytes: vertexIndicies, length: dataSize, options: []) else { fatalError("Couldn't create vertex index buffer") }

            vertexIndexBuffer = buffer
        }
    }
}

// MARK: Utils
extension Renderer {
    fileprivate func computeVertexIndicies() {
        for iiY in 0..<modelHeight-1 {
            for iiX in 0..<modelWidth-1 {
                let topIdx = Int32(iiY)
                let leftIdx = Int32(iiX)
                let bottomIdx = Int32(iiY+1)
                let rightIdx = Int32(iiX+1)

                vertexIndicies.append(contentsOf: [leftIdx, topIdx])
                vertexIndicies.append(contentsOf: [rightIdx, topIdx])
                vertexIndicies.append(contentsOf: [rightIdx, bottomIdx])

                vertexIndicies.append(contentsOf: [rightIdx, bottomIdx])
                vertexIndicies.append(contentsOf: [leftIdx, bottomIdx])
                vertexIndicies.append(contentsOf: [leftIdx, topIdx])
            }
        }
    }
}

// MARK: Renderer State
extension Renderer {

}
