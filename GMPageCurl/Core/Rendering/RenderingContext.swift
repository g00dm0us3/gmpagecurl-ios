//
//  RenderingContext.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 2/1/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import Foundation
import Metal
import UIKit
import simd

internal final class RenderingContext {

    /// Reusable

    private(set) var computePositionsPipelineState: MTLComputePipelineState!
    private(set) var computeNormalsPipelineState: MTLComputePipelineState!

    private(set) var shadowPipelineState: MTLRenderPipelineState!
    private(set) var depthStencilStateForShadowPass: MTLDepthStencilState!
    private(set) var colorPipelineState: MTLRenderPipelineState!
    private(set) var depthStencilStateForColorPass: MTLDepthStencilState!

    private(set) var depthTexture: MTLTexture!
    private(set) var computedPositions: MTLTexture! // positions textures
    private(set) var computedNormals: MTLTexture!
    
    /// Constant
    let perspectiveMatrix: simd_float4x4 = simd_float4x4()
    let lightMatrix: simd_float4x4 = simd_float4x4()

    private(set) var worldMatrix: simd_float4x4 = simd_float4x4()
    private(set) var lightModelMatrix: simd_float3x3 = simd_float3x3()
    /*{
        let lightModelMatrix = simd_float3x3([
            simd_float3(worldMatrix[0][0], worldMatrix[0][1], worldMatrix[0][2]),
            simd_float3(worldMatrix[1][0], worldMatrix[1][1], worldMatrix[1][2]),
            simd_float3(worldMatrix[2][0], worldMatrix[2][1], worldMatrix[2][2])]).inverse
        return lightModelMatrix.transpose
    }*/

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
        
        initMatrices()
    }

    func buildTransientState(for drawable: CAMetalDrawable) -> MTLCommandBuffer {
        drawableSize = CGSize(width: drawable.texture.width, height: drawable.texture.height)

        depthAttachmentDescriptorForColorPass = buildDepthAttachmentDescriptorForColorPass()
        depthAttachemntDescriptorForShadowPass = buildDepthAttachmentDescriptorForShadowPass()
        didUpdateDrawableSize = false

        return commandQueue.makeCommandBuffer()!
    }
    
    // MARK: Private Interface
    private func initMatrices() {
        fatalError("Not implemented!")
    }

    private func buildDepthAttachmentDescriptorForColorPass() -> MTLRenderPassDepthAttachmentDescriptor {
        let depthAttachemntDescriptor = MTLRenderPassDepthAttachmentDescriptor()

        if depthTextureForColorPass == nil || didUpdateDrawableSize {
            let regularTextureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: false)
            regularTextureDesc.storageMode = .private
            regularTextureDesc.mipmapLevelCount = 1
            regularTextureDesc.textureType = .type2D
            regularTextureDesc.usage = [.shaderRead, .renderTarget]
            depthTextureForColorPass = device.makeTexture(descriptor: regularTextureDesc)
        }

        //depthAttachemntDescriptor.resolveTexture = depthTexture
        //depthAttachemntDescriptor.texture = msTexture
        depthAttachemntDescriptor.texture = depthTextureForColorPass
        depthAttachemntDescriptor.loadAction = .clear
        //depthAttachemntDescriptor.storeAction = .multisampleResolve // not available in simulator
        depthAttachemntDescriptor.storeAction = .dontCare
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

    private func makeOutputComputeTexture(pixelFormat: MTLPixelFormat, width: Int, height: Int) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)

        textureDescriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { fatalError("Couldn't create texture")}

        return texture
    }
}
