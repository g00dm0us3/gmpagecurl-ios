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
    fileprivate let modelWidth = 100
    fileprivate let modelHeight = 200
    
    private var defaultLibrary: MTLLibrary!
    private var device: MTLDevice {
        return RenderingDevice.defaultDevice
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
    
    init(_ view: UIView, underlyingView: UIView) {
        state = RendererState(RenderingDevice.defaultDevice, modelWidth: modelWidth, modelHeight: modelHeight)
        worldState = WorldState()
        renderingView = view
        defaultLibrary = RenderingDevice.defaultDevice.makeDefaultLibrary()
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
        computePositionsPassEncoder.setTexture(computedPositions, index: 0)
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

        var radius = worldState.distance
        var phi = superPhi//worldState.phi
        var viewState = 0 // 1 will produce a box view, not very useful, only when debugging geometry

        memcpy(inputBuifferPointer, &radius, MemoryLayout<Float>.size)
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
                
                vertexIndicies.append(contentsOf: [leftIdx, topIdx])
                vertexIndicies.append(contentsOf: [leftIdx, bottomIdx])
                vertexIndicies.append(contentsOf: [rightIdx, bottomIdx])
            }
        }
    }
}

// MARK: Renderer State
extension Renderer {
    fileprivate final class RendererState {
        
        /// Reusable
        
        private(set) var computePositionsPipelineState: MTLComputePipelineState!
        private(set) var computeNormalsPipelineState: MTLComputePipelineState!
        
        private(set) var shadowPipelineState: MTLRenderPipelineState!
        private(set) var depthStencilStateForShadowPass: MTLDepthStencilState!
        private(set) var colorPipelineState: MTLRenderPipelineState!
        private(set) var depthStencilStateForColorPass: MTLDepthStencilState!
        
        private(set) var depthTexture: MTLTexture!
        private(set) var computedPositions:MTLTexture! // positions textures
        private(set) var computedNormals: MTLTexture!
        
        /// Transient
        
        private(set) var depthAttachemntDescriptorForShadowPass: MTLRenderPassDepthAttachmentDescriptor!
        private(set) var depthAttachmentDescriptorForColorPass: MTLRenderPassDepthAttachmentDescriptor!
        
        /// Private
        
        private var depthTextureForColorPass: MTLTexture!
        private var library: MTLLibrary
        private var device: MTLDevice
        
        private var didUpdateDrawableSize = false
        private var innerDrawableSize: CGSize = .zero
        private var drawableSize: CGSize {
            get { return innerDrawableSize }
            set {
                guard newValue != innerDrawableSize else { return }
                innerDrawableSize = newValue
                didUpdateDrawableSize = true
            }
        }
        
        private var commandQueue: MTLCommandQueue

        init(_ device: MTLDevice, modelWidth: Int, modelHeight: Int) {
            self.device = device
            self.commandQueue = self.device.makeCommandQueue()!
            library = device.makeDefaultLibrary()!
            self.computePositionsPipelineState = createKernelPipelineState("compute_positions")
            self.computeNormalsPipelineState = createKernelPipelineState("compute_normals")
            self.shadowPipelineState = try! makeShadowPipelineState()
            self.colorPipelineState = try! makeColorPipelineState()
            
            var depthDescriptor = MTLDepthStencilDescriptor()
            depthDescriptor.depthCompareFunction = .lessEqual
            depthDescriptor.isDepthWriteEnabled = true
            
            depthStencilStateForShadowPass = device.makeDepthStencilState(descriptor: depthDescriptor)
            
            depthDescriptor = MTLDepthStencilDescriptor()
            depthDescriptor.depthCompareFunction = .lessEqual
            depthDescriptor.isDepthWriteEnabled = true
            depthStencilStateForColorPass = device.makeDepthStencilState(descriptor: depthDescriptor)
            
            computedPositions = makeOutputComputeTexture(pixelFormat: .rgba32Float, width: modelWidth, height: modelHeight)
            computedNormals = makeOutputComputeTexture(pixelFormat: .rgba32Float, width: modelWidth, height: modelHeight)
        }
        
        func buildTransientState(for drawable: CAMetalDrawable) -> MTLCommandBuffer {
            drawableSize = CGSize(width: drawable.texture.width, height: drawable.texture.height)
            
            depthAttachmentDescriptorForColorPass = buildDepthAttachmentDescriptorForColorPass()
            depthAttachemntDescriptorForShadowPass = buildDepthAttachmentDescriptorForShadowPass()
            didUpdateDrawableSize = false
            
            return commandQueue.makeCommandBuffer()!
        }
        
        private func buildDepthAttachmentDescriptorForColorPass() -> MTLRenderPassDepthAttachmentDescriptor {
            let depthAttachemntDescriptor = MTLRenderPassDepthAttachmentDescriptor()
            
            if depthTextureForColorPass == nil || didUpdateDrawableSize {
                let regularTextureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: false)
                regularTextureDesc.storageMode = .private
                regularTextureDesc.mipmapLevelCount = 1
                regularTextureDesc.textureType = .type2D
                regularTextureDesc.usage = [.shaderRead, .renderTarget]
                depthTextureForColorPass = RenderingDevice.defaultDevice.makeTexture(descriptor: regularTextureDesc)
            }
            
            //depthAttachemntDescriptor.resolveTexture = depthTexture
            //depthAttachemntDescriptor.texture = msTexture
            depthAttachemntDescriptor.texture = depthTextureForColorPass
            depthAttachemntDescriptor.loadAction = .clear
            //depthAttachemntDescriptor.storeAction = .multisampleResolve // not available in simulator
            depthAttachemntDescriptor.storeAction = .store
            depthAttachemntDescriptor.clearDepth = 1
            return depthAttachemntDescriptor
        }
        
        private func buildDepthAttachmentDescriptorForShadowPass() -> MTLRenderPassDepthAttachmentDescriptor {
            let depthAttachemntDescriptor = MTLRenderPassDepthAttachmentDescriptor()
            
            if depthTexture == nil || didUpdateDrawableSize {
                let regularTextureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: false)
                regularTextureDesc.storageMode = .private
                regularTextureDesc.mipmapLevelCount = 1
                regularTextureDesc.textureType = .type2D
                regularTextureDesc.usage = [.shaderRead, .renderTarget]
                depthTexture = device.makeTexture(descriptor: regularTextureDesc)
            }
            
            depthAttachemntDescriptor.texture = depthTexture
            depthAttachemntDescriptor.loadAction = .clear
            depthAttachemntDescriptor.storeAction = .store
            depthAttachemntDescriptor.clearDepth = 1
            
            return depthAttachemntDescriptor
        }
        
        private func createKernelPipelineState(_ kernelFunctionName: String) -> MTLComputePipelineState {
            let pipelineStateDescriptor = MTLComputePipelineDescriptor()
            
            pipelineStateDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
            pipelineStateDescriptor.computeFunction = library.makeFunction(name: kernelFunctionName)
            
            do {
                return try device.makeComputePipelineState(descriptor: pipelineStateDescriptor, options: MTLPipelineOption(rawValue: 0), reflection: nil)
            } catch {
                fatalError("Cannot create kernel function")
            }
        }
        
        private func makeShadowPipelineState() throws -> MTLRenderPipelineState {
            let vertexProgram = library.makeFunction(name: "vertex_pos_only")

            let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
            pipelineStateDescriptor.vertexFunction = vertexProgram
            pipelineStateDescriptor.fragmentFunction = nil

            pipelineStateDescriptor.depthAttachmentPixelFormat = .depth32Float
            pipelineStateDescriptor.colorAttachments[0].pixelFormat = .invalid

            return try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        }
        
        private func makeColorPipelineState() throws -> MTLRenderPipelineState {
            let vertexProgram = library.makeFunction(name: "vertex_function")
            let fragmentProgram = library.makeFunction(name: "fragment_function")

            let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
            pipelineStateDescriptor.vertexFunction = vertexProgram
            pipelineStateDescriptor.fragmentFunction = fragmentProgram
            
            //pipelineStateDescriptor.sampleCount = 4

            pipelineStateDescriptor.depthAttachmentPixelFormat = .depth32Float
            pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm

            return try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        }
        
        private func makeOutputComputeTexture(pixelFormat: MTLPixelFormat, width: Int, height: Int) -> MTLTexture
        {
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
            
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else { fatalError("Couldn't create texture")}
            
            return texture
        }
    }
}
