//
//  ComputeKernel.metal
//  GMPageCurl
//
//  Created by g00dm0us3 on 4/24/19.
//  Copyright © 2019 Homer. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

/*float4 calculate_position(packed_float3 position, float phi, float xCoord) {
    packed_float3 vi = position;
    float HalfCircumferenceOfBase = PI*CYLINDER_RADIUS;
    
    float xt = 0, yt = 0, zt = 0;
    
    float cylinderCenterX = xCoord - vi.y*sin(phi);
    float cylinderCenterY = vi.y*cos(phi);
    
    if(vi.x <= cylinderCenterX) { // no deformation normal doesnt change
        return float4(vi,1);
    }
    
    float x1 = vi.x-cylinderCenterX;
 //rewrite in a form that allows differentiation
 //differentiate by xt, yt, zt by vi.x, vi.y, vi.z EACH!
 //should get a 3x3 matrix J
 // then Normal = (J^T)^-1.Normal
    if(x1 <= HalfCircumferenceOfBase) {
    //x1 = (vi.x-xCoord - vi.y*sin(phi))
        float beta =  (vi.x-xCoord - vi.y*sin(phi))/CYLINDER_RADIUS;
        xt = xCoord - vi.y*sin(phi)+(CYLINDER_RADIUS*sin((vi.x-xCoord - vi.y*sin(phi))/CYLINDER_RADIUS));
        yt = (xt - xCoord + vi.y*sin(phi))*sin(phi)+(vi.y-vi.y*cos(phi))*cos(phi)+vi.y*cos(phi);
        zt = CYLINDER_RADIUS * (1.0 - cos((vi.x-xCoord - vi.y*sin(phi))/CYLINDER_RADIUS)); //beware - depending on initial z-position in model, this may work incorrectly check direction of z
        
    } else {
        float hD1 = ((vi.x-xCoord - vi.y*sin(phi))/CYLINDER_RADIUS - HalfCircumferenceOfBase);
        
        xt = xCoord - vi.y*sin(phi)-((vi.x-xCoord - vi.y*sin(phi))/CYLINDER_RADIUS - HalfCircumferenceOfBase);
        yt = ((xCoord - vi.y*sin(phi)-((vi.x-xCoord - vi.y*sin(phi))/CYLINDER_RADIUS - HalfCircumferenceOfBase)) - xCoord + vi.y*sin(phi))*sin(phi)+(vi.y-vi.y*cos(phi))*cos(phi)+vi.y*cos(phi);
        
        zt = 2*CYLINDER_RADIUS;
    }
    
    //now rotate x,y around cylinderCenter coords
    
    xt= (xt - cylinderCenterX)*cos(phi)-(vi.y-cylinderCenterY)*sin(phi)+cylinderCenterX;
 
    
    float4 pos = float4(xt, yt, zt,1);
    
    return pos;
}

kernel void adjust_pos_normals(device VertexIn *vertices [[buffer(0)]],
                             constant Uniforms &uniforms [[buffer(1)]],
                             constant Input &input[[buffer(2)]],
                             device float3 *outBuffer,
                             uint2 gid [[thread_position_in_grid]]) { //grid - whatever the hell you want (per pixel or whatever)
 //make grid the size of the mesh treat vertices in an array
    
    
}*/




