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

final class RenderingPipeline {
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue!

    init() {
        device = RenderingDevice.defaultDevice
        commandQueue = device.makeCommandQueue()
    }

    public func getCommandBuffer() -> MTLCommandBuffer {
        return commandQueue.makeCommandBuffer()! //make stored property
    }

    public func renderPassDescriptor() -> MTLRenderPassDescriptor {
        let renderPassDscriptor = MTLRenderPassDescriptor()
        
        renderPassDscriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPassDscriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
        renderPassDscriptor.colorAttachments[0].storeAction = MTLStoreAction.multisampleResolve

        return renderPassDscriptor
    }

    public func makeInputComputeTexture(pixelFormat: MTLPixelFormat, width: Int, height: Int) -> MTLTexture
    {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        
        textureDescriptor.usage = [.shaderRead]
        //textureDescriptor.storageMode = .shared
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { fatalError("Couldn't create texture")}
        
        return texture
    }
    
    public func makeOutputComputeTexture(pixelFormat: MTLPixelFormat, width: Int, height: Int) -> MTLTexture
    {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        //textureDescriptor.storageMode = .shared
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { fatalError("Couldn't create texture")}
        
        return texture
    }
}
