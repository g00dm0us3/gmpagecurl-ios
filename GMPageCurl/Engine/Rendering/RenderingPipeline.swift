//
//  RenderingPipeline.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 4/23/19.
//  Copyright © 2019 Homer. All rights reserved.
//

import Foundation
import Metal
import UIKit

class RenderingPipeline {
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue!
    private var defaultLibrary: MTLLibrary!
    
    
    //render pass descriptors
    private(set) var shadowRenderPassDescriptor: MTLRenderPassDescriptor? = nil
    
    //pipeline states
    
    private(set) var colorPipelineState: MTLRenderPipelineState? = nil
    private(set) var shadowPipelineState: MTLRenderPipelineState? = nil
    
    //depth stencil state
    
    private(set) var shadowDepthStencilState: MTLDepthStencilState? = nil
    private(set) var depthStencilState: MTLDepthStencilState? = nil
    
    private(set) var shadowTexture: MTLTexture?
    private var depthTexture:MTLTexture?
    
    init(){
        device = RenderingDevice.shared.device
        commandQueue = device.makeCommandQueue()
        defaultLibrary = device.makeDefaultLibrary()
        shadowTexture = createShadowTexture()
        depthTexture = createDepthTexture()
        
        shadowRenderPassDescriptor = renderPassDescriptorForShadow()
        
        colorPipelineState = try! initColorPipelineState()
        shadowPipelineState = try! initShadowPipelineState()
        
        //differ by comparison function
        shadowDepthStencilState = makeShadowDepthStencilState()
        depthStencilState = makeDepthStencilState()
        
    
    }
    public func getCommandBuffer() -> MTLCommandBuffer {
        return commandQueue.makeCommandBuffer()! //make stored property
    }
    
    private func getComputePipelineState() throws ->MTLComputePipelineState {
        let adjustmentFunction = defaultLibrary.makeFunction(name: "adjust_pos_normals")!
        return try device.makeComputePipelineState(function: adjustmentFunction)
    }
    
    public func adjustVertices(vertexBuffer: MTLBuffer,
                               inputBuffer: MTLBuffer,
                               commandBuffer:MTLCommandBuffer,
                               meshSize:(rows: Int, cols: Int)) throws {
        
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()! //todo: add guard here, conform to Error protocol
        let computePipelineState = try getComputePipelineState()
        
        computeCommandEncoder.setComputePipelineState(computePipelineState)
        computeCommandEncoder.setBuffer(vertexBuffer, offset: 0, index: 0)
        computeCommandEncoder.setBuffer(inputBuffer, offset: 0, index:1)
        computeCommandEncoder.dispatchThreadgroups(
            MTLSize(width: meshSize.rows*meshSize.cols, height: 1, depth: 1), //take all the vertices , todo: make grid 2d
            threadsPerThreadgroup: MTLSize(width: 4, height: 1, depth: 1)) // process 4 simultaneously
        computeCommandEncoder.endEncoding()
    }
    
    
    public func renderPassDescriptorForTexture(texture: MTLTexture!) -> MTLRenderPassDescriptor {
        let renderPassDscriptor = MTLRenderPassDescriptor()
        renderPassDscriptor.colorAttachments[0].texture = texture
        renderPassDscriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPassDscriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
        renderPassDscriptor.colorAttachments[0].storeAction = MTLStoreAction.store
        
        let shadowAttachment = renderPassDscriptor.depthAttachment
        shadowAttachment?.texture = depthTexture!
        shadowAttachment?.loadAction = .clear
        shadowAttachment?.storeAction = .store
        shadowAttachment?.clearDepth = 1.0
        
        return renderPassDscriptor
        
    }
    
    public func renderTo(drawable: CAMetalDrawable!) {
        
        
    }
    
    
    
    private func initColorPipelineState() throws -> MTLRenderPipelineState {
        let device = RenderingDevice.shared.device!
        
        //for some reason model buffer creation was here
        
        let vertexProgram = defaultLibrary.makeFunction(name: "vertex_function")
        let fragmentProgram = defaultLibrary.makeFunction(name: "fragment_function")
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        pipelineStateDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        
        
        return try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    }
    
    private func initShadowPipelineState() throws -> MTLRenderPipelineState {
        let device = RenderingDevice.shared.device!
        
        let shadowVertexFunction = defaultLibrary.makeFunction(name: "vertex_zOnly")
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = shadowVertexFunction
        pipelineDescriptor.fragmentFunction = nil
        pipelineDescriptor.colorAttachments[0].pixelFormat = .invalid
        pipelineDescriptor.depthAttachmentPixelFormat =  .depth32Float//shadowTexture.pixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func makeDepthStencilState() -> MTLDepthStencilState {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        
        
        return device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
        
    }
    
    private func makeShadowDepthStencilState() -> MTLDepthStencilState {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .lessEqual
        depthStencilDescriptor.isDepthWriteEnabled = true
        
        return device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
    }
    
    
    
    private func createShadowTexture() -> MTLTexture{
        let device = RenderingDevice.shared.device!
        
        let shadowTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float,
                                                                               width: 2*375, height: 2*667,
                                                                               mipmapped: false)
        shadowTextureDescriptor.usage = [.shaderRead, .renderTarget]
        let shadowTexture = device.makeTexture(descriptor: shadowTextureDescriptor)
        shadowTexture!.label = "shadow map"
        
        return shadowTexture!;
    }
    
    private func createDepthTexture() -> MTLTexture{
        let device = RenderingDevice.shared.device!
        
        let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float,
                                                                               width: 375, height: 667,
                                                                               mipmapped: false)
        depthTextureDescriptor.usage = [.shaderRead, .renderTarget]
        
        let depthTexture = device.makeTexture(descriptor:depthTextureDescriptor)
        depthTexture!.label = "depth map"
        
        return depthTexture!;
    }
    
    
    private func renderPassDescriptorForShadow() -> MTLRenderPassDescriptor {
        
        let shadowRenderPassDescriptor = MTLRenderPassDescriptor()
        let shadowAttachment = shadowRenderPassDescriptor.depthAttachment
        shadowAttachment?.texture = shadowTexture!
        shadowAttachment?.loadAction = .clear
        shadowAttachment?.storeAction = .store
        shadowAttachment?.clearDepth = 1
        
        return shadowRenderPassDescriptor
    }
    
}
