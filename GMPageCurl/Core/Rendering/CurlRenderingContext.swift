//
//  CurlRenderingContext.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 2/1/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import Foundation
import Metal
import MetalKit
import UIKit
import simd

internal final class CurlRenderingContext {

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
    private(set) var viewTexture: MTLTexture!

    private(set) var inputBuffer: MTLBuffer
    private(set) var uniformBuffer: MTLBuffer
    private(set) var constantUniformBuffer: MTLBuffer
    private(set) var vertexIndexBuffer: MTLBuffer

    let vertexIndiciesCount: Int
    /// Constant

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

    private var modelSize: CGSize

    private var perspectiveMatrix: simd_float4x4 = simd_float4x4()
    private var lightMatrix: simd_float4x4 = simd_float4x4()

    private var worldMatrix: simd_float4x4 = simd_float4x4()
    private var lightModelMatrix: simd_float3x3 = simd_float3x3()

    private var commandQueue: MTLCommandQueue

    private let defaultLibrary: MTLLibrary

    init(_ device: MTLDevice, modelWidth: Int, modelHeight: Int) {
        self.device = device
        self.commandQueue = self.device.makeCommandQueue()!
        self.modelSize = CGSize(width: modelWidth, height: modelHeight)
        self.defaultLibrary = device.makeDefaultLibrary()!

        var totalSz = 2*MatrixUtils.matrix4x4Size
        uniformBuffer = CurlRenderingContext.makeBuffer(totalSz, device: device)

        totalSz = 2*MatrixUtils.matrix4x4Size
        constantUniformBuffer = CurlRenderingContext.makeBuffer(totalSz, device: device)

        totalSz = 2*MemoryLayout<Float>.size+MemoryLayout<Int>.size
        inputBuffer = CurlRenderingContext.makeBuffer(totalSz, device: device)

        vertexIndiciesCount =  CurlRenderingContext.vertexIndiciesCount(sheetSize: CGSize(width: modelWidth, height: modelHeight))
        let dataSize = vertexIndiciesCount * MemoryLayout<Int32>.size
        vertexIndexBuffer = CurlRenderingContext.makeBuffer(dataSize, device: device)

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
        fillConstantBuffers()
    }

    /// Prepares rendering context for rendering.
    ///  - Note: call before each render pass
    /// - Parameter drawable: drawable used as a final rendering destination
    /// - Parameter params: parameters of a curl
    /// - Parameter viewImage: image of a view (which was showing), to use as a texture in color pass
    /// - Returns: command buffer, to use for render pass commands encoding
    func prepare(with drawable: CAMetalDrawable, params: CurlParams, viewImage: UIImage) -> MTLCommandBuffer {
        drawableSize = CGSize(width: drawable.texture.width, height: drawable.texture.height)

        depthAttachmentDescriptorForColorPass = buildDepthAttachmentDescriptorForColorPass()
        depthAttachemntDescriptorForShadowPass = buildDepthAttachmentDescriptorForShadowPass()
        didUpdateDrawableSize = false

        let textureLoader = MTKTextureLoader(device: device)
        viewTexture = try! textureLoader.newTexture(cgImage: viewImage.cgImage!, options: nil)
        fillCurlParamsBuffer(curlParams: params)

        return commandQueue.makeCommandBuffer()!
    }

    // MARK: Private Interface
    private func initMatrices() {
        perspectiveMatrix = MatrixUtils.matrix_ortho(left: -1, right: 1, bottom: -1, top: 1, near: 1, far: -1)//MatrixUtils.matrix_perspective(aspect: 1, fovy: 90.0, near: 0.1, far: 100)

        let ortho = MatrixUtils.matrix_ortho(left: -1, right: 1, bottom: -1, top: 1, near: 1, far: -1)
        //let lightView = MatrixUtils.matrix_lookat(at: simd_float3(0,0,0), eye: simd_float3(0,0,-2), up: simd_float3(0,1,0))
        lightMatrix = ortho

        worldMatrix = MatrixUtils.identityMatrix4x4
        //worldMatrix = modeInput.scaled(1)

        lightModelMatrix = simd_float3x3([
            simd_float3(worldMatrix[0][0], worldMatrix[0][1], worldMatrix[0][2]),
            simd_float3(worldMatrix[1][0], worldMatrix[1][1], worldMatrix[1][2]),
            simd_float3(worldMatrix[2][0], worldMatrix[2][1], worldMatrix[2][2])]).inverse.transpose
    }

    private func fillConstantBuffers() {
        var lightMatrix = self.lightMatrix
        var perspectiveMatrix = self.perspectiveMatrix

        memcpy(constantUniformBuffer.contents(), &lightMatrix, MatrixUtils.matrix4x4Size)
        memcpy(constantUniformBuffer.contents() + MatrixUtils.matrix4x4Size, &perspectiveMatrix, MatrixUtils.matrix4x4Size)

        var worldMatrix = self.worldMatrix
        var lightModelMatrix = self.lightModelMatrix

        memcpy(uniformBuffer.contents(), &worldMatrix, MatrixUtils.matrix4x4Size)
        memcpy(uniformBuffer.contents() + MatrixUtils.matrix4x4Size, &lightModelMatrix, MatrixUtils.matrix4x4Size)

        var vertexIndiciesArray = computeVertexIndicies(sheetSize: modelSize)
        memcpy(vertexIndexBuffer.contents(), &vertexIndiciesArray, vertexIndiciesCount*MemoryLayout<Int32>.size)
    }

    private func fillCurlParamsBuffer(curlParams: CurlParams) {
        let inputBufferPointer = inputBuffer.contents()

        var radius = curlParams.delta
        var phi = curlParams.phi
        var viewState = 0 // 1 will produce a box view, not very useful, only when debugging geometry

        memcpy(inputBufferPointer, &radius, MemoryLayout<Float>.size)
        memcpy(inputBufferPointer + MemoryLayout<Float>.size, &phi, MemoryLayout<Float>.size)
        memcpy(inputBufferPointer + 2*MemoryLayout<Float>.size, &viewState, MemoryLayout<Int>.size)
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

// MARK: Utils
extension CurlRenderingContext {
    fileprivate static func makeBuffer(_ size: Int, device: MTLDevice) -> MTLBuffer {
        guard let buffer = device.makeBuffer(length: size, options: []) else { fatalError("Couldn't create a uniform buffer") }
        return buffer
    }

    fileprivate static func vertexIndiciesCount(sheetSize: CGSize) -> Int {
        return 2*6*Int(sheetSize.height-1)*Int(sheetSize.width - 1)
    }

    fileprivate func computeVertexIndicies(sheetSize: CGSize) -> [Int32] {
        let modelHeight = Int(sheetSize.height)
        let modelWidth = Int(sheetSize.width)

        var vertexIndicies = [Int32]()

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

        return vertexIndicies
    }
}
