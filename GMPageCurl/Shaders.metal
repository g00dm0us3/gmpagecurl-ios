//
//  Shaders.metal
//  GMPageCurl
//
//  Created by g00dm0us3 on 3/15/19.
//  Copyright © 2019 g00dm0us3. All rights reserved.
//


#include <metal_stdlib>
#include <simd/simd.h>

#define PI 3.1415926535897
#define CYLINDER_RADIUS 0.2

#define PHI_EPSILON 1e-2
#define EPSILON 1e-6

using namespace metal;

typedef struct
{
    packed_float3 position;
    packed_float4 color;
} VertexIn;

typedef struct {
    float4 position [[position]];
    float3 orig; // used for debugging (position, w/o multiplication by model and perspective matrices)
    half4  color;
} VertexOut;

typedef struct {
    float4x4 modelMatrix;
    float4x4 perspectiveMatrix;
} Uniforms;

typedef struct {
    float xCoord;
    float phi;
    int state;
} Input;

inline float2 flip(float2 v) {
    return float2(v.x*cos(PI)-v.y*sin(PI), v.x*sin(PI)+v.y*cos(PI));
}

// rotates clockwise
inline float2 rot(float2 point, float angle)
{
    matrix_float2x2 mat = matrix_float2x2(float2(cos(angle), sin(angle)), float2(-sin(angle), cos(angle)));
    return mat*point;
}

inline bool should_transform(packed_float3 vi, float phi, float xCoord) {
    if(xCoord > 1) return false;
    
    if(abs(phi) < PHI_EPSILON) {
        return vi.x > xCoord;
    }

    float2 a = rot(float2(xCoord, 1), phi);
    float2 b = rot(float2(xCoord, -1), phi);
    
    /// @note:  Fast Robust Prdicates For Computational Geometry, https://www.cs.cmu.edu/~quake/robust.html
    
    float3x3 mat = float3x3(float3{a.x, b.x, vi.x}, float3{a.y, b.y, vi.y}, float3{ 1.0, 1.0, 1.0});
    
    float det = determinant(mat);
    
    if(abs(det) <= EPSILON)
        det = 0.0;
    
    return sign(det) >= 0 ;

}

inline float2 calcPointOnDisplacementBorder(float2 pointOnPlane, float phi, float xCoord)
{
    if (phi == 0) {
        return float2(xCoord, pointOnPlane.y);
    }
    
    float2 direction = float2(cos(phi), sin(phi));
    direction *= xCoord;

    float2 vecBegin = direction;
    float2 vecEnd = pointOnPlane;
    
    float2 v = rot(vecEnd - vecBegin, -phi); // rotated by -𝛗, translated to the Metal coordinate origin
    float2 vertical = float2(0, v.y);

    vertical = rot(vertical, phi);
    vertical += vecBegin;
    
    return vertical;
}

inline float4 calculate_position(packed_float3 position, float phi, float xCoord, int viewState) {
    if (xCoord == 0) { return float4(position.xyz,1); }
    xCoord = 1 - xCoord; // conversion to the Metal coordinate system
    
    bool isOnBorder = should_transform(position, phi, xCoord);
    bool isWithinRadius = should_transform(position, phi, xCoord - CYLINDER_RADIUS) && (viewState == 0);
    
    if (!isOnBorder && !isWithinRadius) {
        return float4(position.x, position.y, position.z, 1);
    }
    
    float3 pointOnBox;
    
    /**
       Box:
     
       Roof:
       ___________
                 |
                 |
                 |
                 | <- Wall
                 |
       ___________|
        Floor
    */
    
    float2 pointOnPlane = float2(position.x, position.y);
    
    if (isWithinRadius && !isOnBorder) {
        pointOnPlane.x = xCoord;
        pointOnPlane.y = 0;

        pointOnPlane = rot(pointOnPlane, phi) + position.xy;
    }
    
    float2 pointOnDisplacementBorder = calcPointOnDisplacementBorder(pointOnPlane, phi, xCoord);
    
    if (isOnBorder) {
        
        /* point where cylinder touches the plane of the sheet of paper, it's to the left, cylinder is inside the "walls" */
        
        float len = distance(pointOnDisplacementBorder, pointOnPlane);
        
        if (len > 2*CYLINDER_RADIUS) { // roof
            float z = 2*CYLINDER_RADIUS;
            
            float convertedX = pointOnPlane.x - pointOnDisplacementBorder.x;
            float convertedY = pointOnPlane.y - pointOnDisplacementBorder.y;
            
            float2 v = float2(convertedX, convertedY);
            
            v = normalize(v);
            v *= (len - 2*CYLINDER_RADIUS);
            v = flip(v);
            
            v += pointOnDisplacementBorder;
            
            pointOnBox = float3(v.xy, z);
        } else {
            pointOnBox = float3(pointOnDisplacementBorder.xy, len);
        }
    } else {
            pointOnBox = float3(position.xyz);
    }
    
    if (viewState == 1) { // for demo purposes, do no make it cylindrical
        return float4(pointOnBox.xyz, 1);
    }
    
    float2 reciprocal = CYLINDER_RADIUS*flip(float2(cos(phi), sin(phi)));
    float2 pointOnCylinderTangent = pointOnDisplacementBorder + reciprocal;
    
    float3 pointOnCylinderAxis = float3(pointOnCylinderTangent.xy, CYLINDER_RADIUS);
    
    // pointOnDisplacementBorder no longer needed
    float3 axisToBox = float3(pointOnBox - pointOnCylinderAxis);
    
    float3 testVec = float3(1, 0, 0);
    float angle = acos(dot(normalize(axisToBox), normalize(testVec)));
    
    if (angle >= PI / 2) {
        return float4(pointOnBox.xyz, 1);
    }
    
    // Convert point on box into a point on cylinder inside this box
    axisToBox = normalize(axisToBox);

    axisToBox *= CYLINDER_RADIUS;
    axisToBox += pointOnCylinderAxis;
    
    return float4(axisToBox.xyz, 1);
}

kernel void compute_positions(const texture2d<float> vertices [[texture(0)]],
                              texture2d<float, access::write> transformed [[texture(1)]],
                              constant Input &input[[buffer(0)]],
                              uint2 tid [[thread_position_in_grid]])
{
    if (tid.x >= vertices.get_width() || tid.y >= vertices.get_height()) {
        return;
    }

    float4 r = vertices.read(tid.xy);
    float3 position = float3(r.x,r.y,r.z);
    
    transformed.write(float4(position.xyz, 1), tid);
}

vertex VertexOut vertex_function(const device VertexIn *vertices [[buffer(0)]],
                                 constant Uniforms &uniforms [[buffer(1)]],
                                 constant Input &input[[buffer(2)]],
                                 uint vid [[vertex_id]])
{
    VertexOut out;
    
    float phi = input.phi;
    float xCoord = input.xCoord;
    
    float4 pos = calculate_position(vertices[vid].position, phi, xCoord, input.state);

    out.orig = float3(pos.xyz);
    out.position = uniforms.perspectiveMatrix * uniforms.modelMatrix * pos;
    out.color = half4(vertices[vid].color);
    
    return out;
}

fragment float4 fragment_function(VertexOut in [[stage_in]])
{
    return float4(in.color);
}
