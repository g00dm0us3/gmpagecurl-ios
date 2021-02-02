//
//  CurlRenderer.swift
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

final class CurlRenderer {
    private var currentDrawable: CAMetalDrawable?

    // should correspond to the #defines in shader
    fileprivate let modelWidth = 105
    fileprivate let modelHeight = 210

    private var device: MTLDevice {
        return DeviceWrapper.device
    }

    private let context: CurlRenderingContext

    private var computedNormals: MTLTexture {
        return context.computedNormals!
    }

    private var computedPositions: MTLTexture {
        return context.computedPositions!
    }

    var cadDisplayLink: CADisplayLink!
    weak var renderingView: UIView?
    weak var underlyingView: UIView?

    var superPhi = CGFloat(0)
    var superRadius = CGFloat(0)

    private var isRunningPlayBack = false

    init(_ view: UIView) {
        context = CurlRenderingContext(DeviceWrapper.device, modelWidth: modelWidth, modelHeight: modelHeight)
        renderingView = view
        
        cadDisplayLink = CADisplayLink(target: self, selector: #selector(redraw))
        cadDisplayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
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
        defer {
            //cadDisplayLink.isPaused = true
            //underlyingView?.setNeedsDisplay()
        }

        let playBackStep = CGFloat(0.09)
        if isRunningPlayBack {
            if superRadius - playBackStep <= 0 {
                superRadius = 0
                superPhi = 0
                isRunningPlayBack = false
            } else {
                superRadius -= playBackStep
            }
        }

        let drawable = self.drawable(from: layer)

        let newCommandBuffer = context.prepare(with: drawable, andCurlParams: CurlParams(phi: superPhi, delta: superRadius))

        computePositionsPass(newCommandBuffer)
        shadowRenderPass(newCommandBuffer, (drawable.texture.width, drawable.texture.height))
        colorRenderPass(newCommandBuffer, drawable)

        newCommandBuffer.present(drawable)
        newCommandBuffer.commit()
    }

    private func computePositionsPass(_ commandBuffer: MTLCommandBuffer) {
        let computePositionsPassEncoder = commandBuffer.makeComputeCommandEncoder()!

        computePositionsPassEncoder.pushDebugGroup("COMPUTE POSITIONS")
        let computePositionsPipelineState = context.computePositionsPipelineState!
        let computeNormalsPipelineState = context.computeNormalsPipelineState!

        computePositionsPassEncoder.setComputePipelineState(computePositionsPipelineState)
        computePositionsPassEncoder.setTexture(computedPositions, index: 0)
        computePositionsPassEncoder.setBuffer(context.inputBuffer, offset: 0, index: 0)

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

    private func shadowRenderPass(_ commandBuffer: MTLCommandBuffer, _ size: (width: Int, height: Int)) {
        // MARK: Setup Render Pass Descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.depthAttachment = context.depthAttachemntDescriptorForShadowPass!

        // MARK: Setup Render Pipeline State
        let shadowPipelineState = context.shadowPipelineState!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.pushDebugGroup("SHADOW")

        // cull & front facing
        renderEncoder.setRenderPipelineState(shadowPipelineState)
        renderEncoder.setDepthStencilState(context.depthStencilStateForShadowPass!)

        renderEncoder.setVertexBuffer(context.uniformBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(context.vertexIndexBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(context.constantUniformBuffer, offset: 0, index: 2)

        renderEncoder.setVertexTexture(computedPositions, index: 0)
        renderEncoder.setVertexTexture(computedNormals, index: 1) // computed vertices / normals

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: context.vertexIndiciesCount/2)
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
        renderPassDescriptor.depthAttachment = context.depthAttachmentDescriptorForColorPass!

        //renderPassDescriptor.colorAttachments[0].texture = msTexture
        //renderPassDescriptor.colorAttachments[0].resolveTexture = drawable.texture
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture

        let colorPipelineState = context.colorPipelineState!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!

        renderEncoder.pushDebugGroup("COLOR")
        renderEncoder.label = "CL"

        renderEncoder.setDepthStencilState(context.depthStencilStateForColorPass!)
        renderEncoder.setRenderPipelineState(colorPipelineState)

        renderEncoder.setVertexBuffer(context.uniformBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(context.vertexIndexBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(context.constantUniformBuffer, offset: 0, index: 2)

        renderEncoder.setVertexTexture(computedPositions, index: 0)
        renderEncoder.setVertexTexture(computedNormals, index: 1) // computed vertices / normals

        renderEncoder.setFragmentTexture(context.depthTexture!, index: 0)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: context.vertexIndiciesCount / 2)
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
}
