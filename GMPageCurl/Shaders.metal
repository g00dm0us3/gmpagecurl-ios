//
//  Shaders.metal
//  GMPageCurl
//
//  Created by g00dm0us3 on 3/15/19.
//  Copyright © 2019 g00dm0us3. All rights reserved.
//


#include <metal_stdlib>
#include <simd/simd.h>

#define PI 3.14159265358979323846
#define CYLINDER_RADIUS 0.07

#define PHI_EPSILON 1e-2
#define EPSILON 1e-6

#define NDT_MAX_COORD 1
#define NDT_MIN_COORD -1

using namespace metal;

typedef struct
{
    packed_float3 position;
    packed_float4 color;
} VertexIn;

typedef struct
{
    int2 tex_coords;
} VertexIndex;

typedef struct {
    float4 position [[position]];
    float4 color;
    float4 texture_coordinate;
    float3 normal;
    float4 fragment_in_light_space;
    float3 fragment_in_model_space;
} VertexOut;

typedef struct {
    float4x4 lightMatrix;
    float4x4 modelMatrix;
    float4x4 perspectiveMatrix;
    float3x3 lightModelMatrix;
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
    matrix_float2x2 mat = matrix_float2x2(float2(cos(angle), sin(angle)),
                                          float2(-sin(angle), cos(angle)));
    return mat*point;
}

inline bool should_transform(packed_float3 vi, float phi, float xCoord) {
    if(xCoord > 1) return false; // corner case
    
    if(abs(phi) < PHI_EPSILON) {
        return vi.x > xCoord;
    }

    float2 a = rot(float2(xCoord, -1), phi);
    float2 b = rot(float2(xCoord, 1), phi);
    
    /// @note:  Fast Robust Prdicates For Computational Geometry, https://www.cs.cmu.edu/~quake/robust.html
    /// @note ccw for a,b,c c on left, det > 0
    
    float3x3 mat = float3x3(float3{a.x, b.x, vi.x}, float3{a.y, b.y, vi.y}, float3{ 1.0, 1.0, 1.0});
    
    float det = determinant(mat);
    
    if(abs(det) <= EPSILON)
        det = 0.0;
    
    return sign(det) <= 0 ;

}

inline float2 get_point_on_inflection_border(float2 pointOnPlane, float phi, float xCoord)
{
    if (phi == 0) {
        return float2(xCoord, pointOnPlane.y);
    }
    
    float2 direction = float2(cos(phi), sin(phi));
    direction *= xCoord;

    float2 vecBegin = direction;
    float2 vecEnd = pointOnPlane;
    
    float2 v = rot(vecEnd - vecBegin, -phi); // rotated by -𝛗, translated to the Metal coordinate origin
    float2 vertical = float2(xCoord, v.y);

    vertical = rot(vertical, phi);
    //vertical += vecBegin;
    
    return vertical;
}

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
 
 Wall is on the infleection border (lower), cylinder is inscribed. The line where cylinder touches a sheet of paper is to the left (-CYL_R from inflection border). Floor is everything to the left of xCoord (!should_transform).
*/

inline float4 calculate_position(packed_float3 position, float phi, float xCoord, int viewState) {
    //return float4(position.xyz,1);
    xCoord = NDT_MAX_COORD - xCoord; // conversion to the Metal coordinate system
    if (xCoord == NDT_MAX_COORD || !should_transform(position, phi, xCoord)) { return float4(position.xyz,1); }
    
    
    bool isOnWall = !should_transform(position, phi, xCoord+3*CYLINDER_RADIUS) && should_transform(position, phi, xCoord+CYLINDER_RADIUS);
    bool isOnRoof = should_transform(position, phi, xCoord+3*CYLINDER_RADIUS);
    bool isOnFloor = !should_transform(position, phi, xCoord+CYLINDER_RADIUS);

    float3 pointOnBox = float3(17,17,17);
    float2 pointOnPlane = float2(position.xy);

    /// @note: Inflection border is one radius to the right, to allow for a flat floor.
    /// @note: Point on inflection border corrensponding to a point on a plane can be obtained by drawing a perpendicular from point on a plane to the inflection border.
    float2 pointOnInflectionBorder = get_point_on_inflection_border(pointOnPlane, phi, xCoord + CYLINDER_RADIUS);
    float len = distance(pointOnInflectionBorder, pointOnPlane);
    
    if(isOnWall) {
        pointOnBox = float3(pointOnInflectionBorder, len);
    } else if(isOnFloor) {
        pointOnBox = float3(pointOnPlane, 0);
    } else if(isOnRoof) { // it's on the roof
        float2 v = (pointOnPlane - pointOnInflectionBorder);
        
        v = flip(v);
        v = normalize(v);
        v *= (len - 2*CYLINDER_RADIUS);
        
        v += pointOnInflectionBorder;
        
        pointOnBox = float3(v, 2*CYLINDER_RADIUS);
    }
    
    if (viewState == 1) { // for demo purposes, shows box
        return float4(pointOnBox, 1);
    }
    
    float2 cylTangentOffsetVec = CYLINDER_RADIUS*float2(cos(phi), sin(phi));
    float2 pointOnCylinderTangent = pointOnInflectionBorder - cylTangentOffsetVec;
    
    float3 pointOnCylinderAxis = float3(pointOnCylinderTangent.xy, CYLINDER_RADIUS);
    float3 axisToBoxVec = float3(pointOnBox - pointOnCylinderAxis);
    
    float3 iVec = float3(1, 0, 0);
    float angle = acos(dot(normalize(axisToBoxVec), iVec));
    
    if (angle >= PI / 2) { // cylinder is inscribed in a box. draw a crossection to understand why this condition is cheecked here.
        return float4(pointOnBox.xyz, 1);
    }
    
    // Convert point on box into a point on cylinder inside this box
    axisToBoxVec = normalize(axisToBoxVec);
    axisToBoxVec *= CYLINDER_RADIUS;
    axisToBoxVec += pointOnCylinderAxis;
    
    return float4(axisToBoxVec, 1);
}

kernel void compute_positions(const texture2d<float> vertices [[texture(0)]],
                              texture2d<float, access::write> transformed [[texture(1)]],
                              constant Input &input[[buffer(0)]],
                              uint2 tid [[thread_position_in_grid]])
{
    if (tid.x >= vertices.get_width() || tid.y >= vertices.get_height()) {
        return;
    }

    float4 input_vertex = vertices.read(tid.xy); // - todo: this doesn't change, no need to pass it from anywhere
    float3 position = packed_float3(input_vertex.x, input_vertex.y, input_vertex.z);
    
    float4 pos = calculate_position(position, input.phi, input.xCoord, input.state);
    
    transformed.write(float4(pos.xyz, 1), tid);
}

kernel void compute_normals(const texture2d<float> vertices [[texture(0)]],
                            const texture2d<float, access::write> normals[[texture(1)]],
                            uint2 tid [[thread_position_in_grid]])
{
    if (tid.x >= vertices.get_width() || tid.y >= vertices.get_height()) {
        return;
    }
    
    float3 point = float3(vertices.read(tid));
    
    float3 top;
    float3 right;
    
    int swap = 1;
    
    if (tid.y+1 < vertices.get_height()) {
        top = vertices.read(uint2(tid.x, tid.y+1)).xyz;
    } else {
        top = vertices.read(uint2(tid.x, tid.y-1)).xyz;
        swap ^= 1;
    }
    
    if (tid.x+1 < vertices.get_width()) {
        right = vertices.read(uint2(tid.x + 1, tid.y)).xyz;
    } else {
        right = vertices.read(uint2(tid.x - 1, tid.y)).xyz;
        swap ^= 1;
    }
    
    float3 v1 = right - point;
    float3 v2 = top - point;
    
    float3 n;
    if (swap == 0) {
        n = cross(v2, v1);
    } else {
        n = cross(v1, v2);
    }
    
    n = normalize(n);
    
    // FOR DEBUG
    //float dotProduct = dot(normalize(float3(1,0,0)), n);
    //float angleCos = max((float)dotProduct, (float)-1.0);
    //angleCos = min(angleCos, (float)1.0);
    
    
    //normals.write(float4(angleCos, 0, 0, 180*acos(angleCos)/PI), tid);
    normals.write(float4(float3(point.x, point.y, n.z), 1), tid);
}

vertex VertexOut vertex_function(texture2d<float> tex_vertices [[texture(0)]],
                                 texture2d<float> tex_normals [[texture(1)]],
                                 constant Uniforms &uniforms [[buffer(0)]],
                                 constant VertexIndex *tex_indicies [[buffer(1)]],
                                 uint vid [[vertex_id]])
{
    VertexOut out;

    uint2 tex_coord = uint2(tex_indicies[vid].tex_coords.xy);
    float3 position = packed_float3(tex_vertices.read(tex_coord).xyz);

    float4 pos = float4(position.xyz, 1);
    float3 normal = float3(tex_normals.read(tex_coord).xyz);
    
    out.fragment_in_model_space = float3((uniforms.modelMatrix * pos).xyz);
    out.normal = uniforms.lightModelMatrix * normal;
    out.fragment_in_light_space = uniforms.lightMatrix * float4(out.fragment_in_model_space, 1);
    out.texture_coordinate = uniforms.perspectiveMatrix * uniforms.modelMatrix * pos;
    out.position = uniforms.perspectiveMatrix * uniforms.modelMatrix * pos;
    out.color = float4(0,0,1,1);
    
    return out;
}

float calculate_shadow(float4 fragment_in_light_space, depth2d<float> depth) {
    constexpr sampler texSampler(coord::normalized, filter::linear, address::clamp_to_edge, compare_func::less);
    float3 xyz = fragment_in_light_space.xyz / fragment_in_light_space.w;
    float2 xy = xyz.xy;
    xy = xy* 0.5 + 0.5;
    xy.y = 1 - xy.y;
    
    float val = depth.sample(texSampler, xy);
    
    float b = 0.007;
    float shadow = xyz.z - b > val ? 0.5 : 0.0;
    
    return shadow;
}

// make this color / light shader
fragment float4 fragment_function(VertexOut in [[stage_in]], depth2d<float> depth [[texture(0)]])
{
    float3 normal = normalize(in.normal);
    
    float3 light_pos = float3(0,0,0.9);
    
    /// @note: this happens, if there is a roof (normal points downward from there, dot < 0, roof is rendered pitch black)
    float3 light_color = float3(1,1,1);
    if (dot(normal, light_pos) < 0) {
        normal = -normal;
        light_color = float3(0.9, 0.8, 0.8);
    }
    
    // - todo: is it needed?
    //float3 ambient = 0.15*light_color;
    
    float3 light_direction = normalize(light_pos);
    float diff = max(dot(light_direction, normal), (float)0);
    float3 diffuse = diff*light_color;

    float val = calculate_shadow(in.fragment_in_light_space, depth);

    return float4((1-val)*diffuse*(light_color), 1);
}

vertex float4 vertex_pos_only(texture2d<float> tex_vertices [[texture(0)]],
                                 texture2d<float> tex_normals [[texture(1)]],
                                 constant Uniforms &uniforms [[buffer(0)]],
                                 constant VertexIndex *tex_indicies [[buffer(1)]],
                                 uint vid [[vertex_id]])
{
    uint2 tex_coord = uint2(tex_indicies[vid].tex_coords.xy);
    float3 position = packed_float3(tex_vertices.read(tex_coord).xyz);

    float4 pos = float4(position.xyz, 1);

    return uniforms.lightMatrix * uniforms.modelMatrix * pos;
}
