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
    
    init() {
        device = RenderingDevice.defaultDevice
        commandQueue = device.makeCommandQueue()
        defaultLibrary = device.makeDefaultLibrary()
        
        
        colorPipelineState = try! initColorPipelineState()
    }
    
    public func getCommandBuffer() -> MTLCommandBuffer {
        return commandQueue.makeCommandBuffer()! //make stored property
    }
    
    private func getComputePipelineState() throws ->MTLComputePipelineState {
        let adjustmentFunction = defaultLibrary.makeFunction(name: "adjust_pos_normals")!
        return try device.makeComputePipelineState(function: adjustmentFunction)
    }
    
    public func renderPassDescriptorForTexture(texture: MTLTexture!) -> MTLRenderPassDescriptor {
        let renderPassDscriptor = MTLRenderPassDescriptor()
        renderPassDscriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPassDscriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
        renderPassDscriptor.colorAttachments[0].storeAction = MTLStoreAction.store
        
        return renderPassDscriptor
    }

    private func initColorPipelineState() throws -> MTLRenderPipelineState {
        let vertexProgram = defaultLibrary.makeFunction(name: "vertex_function")
        let fragmentProgram = defaultLibrary.makeFunction(name: "fragment_function")
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        pipelineStateDescriptor.depthAttachmentPixelFormat = .invalid
        
        return try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    }
    
}
