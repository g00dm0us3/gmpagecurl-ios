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
#define CYLINDER_RADIUS 0.24

using namespace metal;


typedef struct
{
    packed_float3 position;
    packed_float4 color;
    //packed_float3 normal;
} VertexIn;

typedef struct {
    float4 position [[position]];
    float3 eye;
    float3 orig;
    float3 grid_coord;
    float3 normal;
    half4  color;
    float4 shadow_coord;// [[position]];
} VertexOut;

typedef struct {
    float4x4 modelMatrix;
    float4x4 perspectiveMatrix;
    float4x4 depthBiasMVP;
    float3x3 normalMatrix;
    
} Uniforms;

typedef struct {
    float4x4 depthMVP;
} DepthMVP;

typedef struct {
    float xCoord;
    float phi;
} Input;

struct Light {
    float3 direction;
    float3 ambientColor;
    float3 diffuseColor;
    float3 specularColor;
};

constant Light light = {
    .direction = {0.0, 0.0, 5},
    .ambientColor = {0.05, 0.05, 0.05},
    .diffuseColor = {0.9, 0.9, 0.9},
    .specularColor = {1.0, 1.0, 1.0}
    
};

struct Material
{
    float3 ambientColor;
    float3 diffuseColor;
    float3 specularColor;
    float specularPower;
};

constant Material material = {
    .ambientColor = { 0.1, 0.1, 0.1 },
    .diffuseColor = { 0.1, 0.1, 0.1 },
    .specularColor = { 1, 1, 1 },
    .specularPower = 2
};

float2 cylinder_center(packed_float3 vi, float xCoord, float phi) {
    if(phi == 0) {
        return float2(xCoord, vi.y);
    }
    
    /*float n = xCoord / sin(phi);
    
    float b = vi.y - vi.x*tan(phi);
    
    float cylinderCenterX = (-b+n)/(tan(phi)+(1/tan(phi)));
    float cylinderCenterY = cylinderCenterX*tan(phi)+b;*/
    float cylinderCenterY = vi.y;
    float cylinderCenterX = (xCoord-cylinderCenterY*sin(phi))/cos(phi);
    
    return float2(cylinderCenterX, cylinderCenterY);
}

float2 cylinder_center_norm(packed_float3 vi, float xCoord, float phi) {
    if(phi == 0) {
        return float2(xCoord, vi.y);
    }
    
    float n = xCoord / sin(phi);
     float b = vi.y - vi.x*tan(phi);
     
     float cylinderCenterX = (-b+n)/(tan(phi)+(1/tan(phi)));
     float cylinderCenterY = cylinderCenterX*tan(phi)+b;
    
    return float2(cylinderCenterX, cylinderCenterY);
}

float4 calculate_line_points(float phi, float xCoord) {
    float topX = 0;
    float topY = 0;
    
    float bottomX = 0;
    float bottomY = 0;
    
    float p = xCoord;
    
    
    
    if(phi > 0) {
        topY = 1;
        topX = (p - topY*sin(phi)) / cos(phi);
        
        if (topX < -1) {
            topX = -1;
            topY = (p - topX*cos(phi)) / sin(phi);
        }
        
        bottomY = -1;
        bottomX = (p-bottomY*sin(phi)) / cos(phi);
        
        if(bottomX > 1) {
            bottomX = 1;
            bottomY = (p-bottomX*cos(phi)) / sin(phi);
        }
        
        return float4(topX, topY, bottomX, bottomY);
        
    }
    
    if(phi < 0) {
        topY = 1;
        topX = (p - topY*sin(phi)) / cos(phi);
        
        if (topX > 1) {
            topX = 1;
            topY = (p - topX*cos(phi)) / sin(phi);
        }
        
        bottomY = -1;
        bottomX = (p-bottomY*sin(phi)) / cos(phi);
        
        if(bottomX < -1) {
            bottomX = -1;
            bottomY = (p-bottomX*cos(phi)) / sin(phi);
        }
        
        return float4(topX, topY, bottomX, bottomY);
    }
    
    return float4(xCoord,1, xCoord,-1);
}

bool should_transform(packed_float3 vi, float phi, float xCoord) {
    float2 cyl_cnt = cylinder_center(vi.y, xCoord, phi);
    float4 line_points = calculate_line_points(phi, xCoord);
    
    
    float cylinderCenterX = cyl_cnt.x;
    
    float leftX = line_points[0];
    float leftY = line_points[1];
    
    float rightX = line_points[2];
    float rightY = line_points[3];
    
    //return vi.x > cylinderCenterX;
    
    if(xCoord >= 1) return false;
    
    if(abs(phi) < 1e-2) {
        return vi.x > cylinderCenterX;
    }
    
    float3x3 mat = float3x3(float3{leftX, rightX, vi.x},float3{leftY, rightY, vi.y},float3{ 1.0, 1.0, 1.0});
    
    float det = determinant(mat);
    
    if(abs(det) <= 1e-6)
        det = 0.0;
    
    return sign(det) >= 0 ;

}

float find_y_at_point_on_line(float x1, float y1, float x2, float y2, float x) {
    
    return ((x-x1)/(x2-x1))*(y2-y1)+y1;
}

float2 flip(float2 v) {
    return float2(v.x*cos(PI)-v.y*sin(PI), v.x*sin(PI)+v.y*cos(PI));
}

float2 mix(float2 v1, float2 v2, float a) {
    
    return a*v1+(1-a)*v2;
}


float4 calculate_position(packed_float3 position, float phi, float xCoord) {
    xCoord += CYLINDER_RADIUS; // edge of the page matches finger position
    
    packed_float3 vi = position;
    if(!should_transform(vi, phi, xCoord)) {
        return float4(position.xyz,1);
    }
    
    float2 cylinderCenterT = cylinder_center(vi, xCoord, phi);
    float2 cylinderCenterN = cylinder_center_norm(vi, xCoord, phi);

    float xt = 0, yt = 0, zt = 0;

    float2 pointOnPlane = float2(vi.x,vi.y);
    
    float dst = length(cylinderCenterT-pointOnPlane);
    
    //return float4(cylinderCenterN.x, cylinderCenterN.y, length(cylinderCenterN-pointOnPlane),1);
    if(dst <= 4*CYLINDER_RADIUS) {
        
        
        float beta =  0;
        
        if(dst == 0) {
            beta = -PI/2;
            
        } else {
            float normalizedDst = 0;
            if(dst > 2*CYLINDER_RADIUS) {
                normalizedDst = 4*CYLINDER_RADIUS-dst;
            } else {
                normalizedDst = dst;
            }
            
            beta=atan((2*CYLINDER_RADIUS)/(normalizedDst));
            if(dst > 2*CYLINDER_RADIUS) {
                
                beta = -PI/2+2*beta;
            } else {
                beta = PI/2-2*beta;
            }
        }

        xt =  (cylinderCenterT.x+CYLINDER_RADIUS*cos(beta));
        yt = find_y_at_point_on_line(cylinderCenterT.x, cylinderCenterN.y,vi.x,vi.y, xt);
        zt = CYLINDER_RADIUS+CYLINDER_RADIUS* (sin(beta)); //beware - depending on initial z-position in model, this may work incorrectly check direction of z
    
        return float4(xt, yt, zt,1);
    } else {
        
        float2 dir_vec = (dst-4*CYLINDER_RADIUS)*normalize(float2(cylinderCenterT.x-vi.x, cylinderCenterN.y-vi.y))+float2(cylinderCenterT.x,cylinderCenterN.y);
        
        xt =  dir_vec.x;
        yt = find_y_at_point_on_line(vi.x, vi.y, cylinderCenterT.x, cylinderCenterN.y, xt);
        
        
         return float4(xt, yt, 2*CYLINDER_RADIUS, 1);
   }

}

float3 calculate_normal(packed_float3 vi, float z,float phi, float xCoord) {
    xCoord += CYLINDER_RADIUS; // edge of the page matches finger position
    
    float2 cylinderCenterT = cylinder_center(vi, xCoord, phi);
    float2 cylinderCenterN = cylinder_center_norm(vi, xCoord, phi);

    float dst = length(cylinderCenterN-float2(vi.x, vi.y));
    if(!should_transform(vi, phi, xCoord) || dst > 4*CYLINDER_RADIUS) { // flat thing yo
        float3 tx = float3(1, 0, 0);
        float3 ty = float3(0, 1, 0);
        
        return cross(tx,ty);
    }
    
    float beta =  0;
    
    if(dst == 0) {
        beta = -PI/2;
        
    } else {
        float normalizedDst = 0;
        if(dst > 2*CYLINDER_RADIUS) {
            normalizedDst = 4*CYLINDER_RADIUS-dst;
        } else {
            normalizedDst = dst;
        }
        
        beta=atan((2*CYLINDER_RADIUS)/(normalizedDst));
        if(dst > 2*CYLINDER_RADIUS) {
            
            beta = -PI/2+2*beta;
        } else {
            beta = PI/2-2*beta;
        }
    }
    
    float xt = (cylinderCenterT.x+CYLINDER_RADIUS*cos(beta));
    float yt = find_y_at_point_on_line(vi.x,vi.y, cylinderCenterT.x, cylinderCenterN.y, xt);
    
    float zt = CYLINDER_RADIUS+CYLINDER_RADIUS* (sin(beta)); //beware - depending on initial z-position in model, this may work incorrectly check direction of z
    
    float3 vec1 = float3(xt-cylinderCenterT.x, yt-cylinderCenterN.y, zt-CYLINDER_RADIUS);
    
    float l = length(vec1);
    
    vec1 = normalize(vec1);
    vec1 = 2*l*vec1;
    
    return vec1;
}

vertex VertexOut vertex_function(device VertexIn *vertices [[buffer(0)]],
                                 constant Uniforms &uniforms [[buffer(1)]],
                                 constant Input &input[[buffer(2)]],
                                 uint vid [[vertex_id]])
{
    
    VertexOut out;
    //light direction through perspective matrix
    //eye direction through perspective matrix
    
    out.color = half4(vertices[vid].color);
    
    float phi = input.phi;//0.01*PI;
    float xCoord = input.xCoord;//0.3;
    
    
    float4 pos = float4(vertices[vid].position, 1);

    if(should_transform(vertices[vid].position, phi, xCoord)) {
        pos = calculate_position(vertices[vid].position, phi, xCoord);
    }
    out.orig = float3(pos.xyz);
    
    out.shadow_coord = uniforms.depthBiasMVP*pos;
    float3 norm = calculate_normal(vertices[vid].position, pos.z, phi, xCoord);
    out.normal = uniforms.normalMatrix*norm; //uniforms.normalMatrix
    
    out.grid_coord = float3(vertices[vid].position);
    
    out.position = uniforms.perspectiveMatrix * uniforms.modelMatrix * pos;
    out.eye = -(uniforms.modelMatrix*pos).xyz;
    
    
    return out;
    
}


vertex float4 vertex_zOnly(device VertexIn *vertices [[buffer(0)]],
                           constant DepthMVP &uniforms [[buffer(1)]],
                           constant Input &input[[buffer(2)]],
                           uint vid [[vertex_id]]) {
    
    float4 position =  float4(vertices[vid].position, 1);
    float phi = input.phi;
    float xCoord = input.xCoord;
    if(should_transform(vertices[vid].position, phi, xCoord)) {
        position = calculate_position(position.xyz, phi, xCoord);
    }
    position = uniforms.depthMVP * position;
    return position;
}

float rescale(float val, float ra, float rb, float na, float nb) {
    return (val-ra)*(nb-na)/(rb-ra)+na;
}

float3 lighten_up_color(float3 color) {
    float darkest = 0.95;
    color.x = rescale(color.x, 0, 1, darkest, 1);
    
    color.y = rescale(color.y, 0, 1, darkest, 1);
    
    color.z = rescale(color.z, 0, 1, darkest, 1);
    return color;
}



fragment float4 fragment_function(depth2d<float> shadow_texture [[texture(0)]],
                                  texture2d<float> text_texture [[texture(1)]],
                                  VertexOut in [[stage_in]])
{
    
    return float4(0,0,1,1);
    
    float2 poissonDisk[4] = {
                                 float2( -0.94201624, -0.39906216 ),
                                 float2( 0.94558609, -0.76890725 ),
                                 float2( -0.094184101, -0.92938870 ),
                                 float2( 0.34495938, 0.29387760 )
    };
    constexpr sampler shadow_sampler(coord::normalized, filter::linear, address::clamp_to_edge, compare_func::less);
    constexpr sampler texture_sampler(coord::normalized, filter::linear, address::clamp_to_edge);
    float3 ambientTerm = light.ambientColor * material.ambientColor;
    
    float3 normal = normalize(in.normal);
    float3 pos = in.orig.xyz;
    
    float3 lightDirection = in.orig.xyz - light.direction;
    float len = length(lightDirection);//sqrt(dot(lightDirection, lightDirection));
    lightDirection = normalize(lightDirection);
    
    float dotWithNormal = dot(normal, -lightDirection);
    bool isNegative = dotWithNormal < 0;
    
    if(dotWithNormal < 0) {
        normal = -normal;
        dotWithNormal = dot(normal, -lightDirection);
    }
    float diffuseIntensity = saturate(dotWithNormal);

    float3 diffuseTerm = light.diffuseColor * material.diffuseColor;// * diffuseIntensity;
   // return float4(diffuseTerm,1);
    
    
    float3 specularTerm(0);
    if (diffuseIntensity > 0)
    {
        float3 eyeDirection = normalize(in.eye);
        float3 halfway = normalize(light.direction + eyeDirection);
        float dotWithNormal =dot(normal, halfway);
        float specularFactor = pow(saturate(dotWithNormal), material.specularPower);
        specularTerm = light.specularColor * material.specularColor * specularFactor;
    }
    float multiplier = 1;
    float2 xy = in.shadow_coord.xy;
    float2 xy_grid = in.grid_coord.xy;
    xy.x = (xy.x+1)/2;
    xy.y = 1-((xy.y+1)/2);
    
    xy_grid.x = (xy_grid.x+1)/2;
    xy_grid.y = 1-((xy_grid.y+1)/2);
    if(in.orig.z <= CYLINDER_RADIUS) {
        float bias = 0.004;
        
        float current_sample = in.shadow_coord.z+bias;
        for(int i = 0; i < 4; i++) {
            float shadow_sample = shadow_texture.sample(shadow_sampler, xy+poissonDisk[i]/50);
            if(shadow_sample < current_sample) {
                multiplier -= (current_sample - shadow_sample);
            }
        }
        
        //return float4(diffuseTerm*multiplier + specularTerm*multiplier, 1);
    }
    float3 resulting_color = lighten_up_color((diffuseTerm + specularTerm))*multiplier;
    if(in.orig.z < CYLINDER_RADIUS) {
        float4 tex = text_texture.sample(shadow_sampler, xy_grid);
        return float4(tex.xyz*resulting_color.x, tex.w);
        //resulting_color = resulting_color.x * float3(0.3,0.3,1);
    }
    
    
    return float4(/*ambientTerm +*/ resulting_color, 1);
}


