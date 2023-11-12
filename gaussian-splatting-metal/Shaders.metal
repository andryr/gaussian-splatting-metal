//
//  Shaders.metal
//  gaussian-splatting-metal
//
//  Created by Andry Rafaralahy on 11/10/2023.
//

#include <metal_stdlib>
using namespace metal;

#include "definitions.h"



float3 computeColorFromSH(Gaussian instance, uint deg, float3 dir)
{
    float SH_C0 = 0.28209479177387814f;
    float SH_C1 = 0.4886025119029199f;
    //    float SH_C2[5] = float[5](
    //                              1.0925484305920792f,
    //                              -1.0925484305920792f,
    //                              0.31539156525252005f,
    //                              -1.0925484305920792f,
    //                              0.5462742152960396f
    //                              );
    //    float SH_C3[7] = float[7](
    //                              -0.5900435899266435f,
    //                              2.890611442640554f,
    //                              -0.4570457994644658f,
    //                              0.3731763325901154f,
    //                              -0.4570457994644658f,
    //                              1.445305721320277f,
    //                              -0.5900435899266435f
    //                              );
    // The implementation is loosely based on code for
    // "Differentiable Point-Based Radiance Fields for
    // Efficient View Synthesis" by Zhang et al. (2022)
    /** float3 dir = aPos - campos;
     dir = dir / length(dir);*/
    
    float3 result = SH_C0 * float3(instance.f_dc_0, instance.f_dc_1, instance.f_dc_2);
    
    if (deg > 0) {
        float x = dir.x;
        float y = dir.y;
        float z = dir.z;
        float3 sh1 = float3(instance.f_rest_0, instance.f_rest_1, instance.f_rest_2);
        float3 sh2 = float3(instance.f_rest_3, instance.f_rest_4, instance.f_rest_5);
        float3 sh3 = float3(instance.f_rest_6, instance.f_rest_7, instance.f_rest_8);
        result = result - SH_C1 * y * sh1 + SH_C1 * z * sh2 - SH_C1 * x * sh3;
    }
    /**if (deg > 0)
     {
     float x = dir.x;
     float y = dir.y;
     float z = dir.z;
     result = result - SH_C1 * y * sh[1] + SH_C1 * z * sh[2] - SH_C1 * x * sh[3];
     
     if (deg > 1)
     {
     float xx = x * x, yy = y * y, zz = z * z;
     float xy = x * y, yz = y * z, xz = x * z;
     result = result +
     SH_C2[0] * xy * sh[4] +
     SH_C2[1] * yz * sh[5] +
     SH_C2[2] * (2.0f * zz - xx - yy) * sh[6] +
     SH_C2[3] * xz * sh[7] +
     SH_C2[4] * (xx - yy) * sh[8];
     
     if (deg > 2)
     {
     result = result +
     SH_C3[0] * y * (3.0f * xx - yy) * sh[9] +
     SH_C3[1] * xy * z * sh[10] +
     SH_C3[2] * y * (4.0f * zz - xx - yy) * sh[11] +
     SH_C3[3] * z * (2.0f * zz - 3.0f * xx - 3.0f * yy) * sh[12] +
     SH_C3[4] * x * (4.0f * zz - xx - yy) * sh[13] +
     SH_C3[5] * z * (xx - yy) * sh[14] +
     SH_C3[6] * x * (xx - 3.0f * yy) * sh[15];
     }
     }
     }*/
    result += 0.5f;
    return clamp(result, 0.0f, 1.0f);
}


float3x3 computeCov3D(float3 scale, float4 rot)
{
    // Create scaling matrix
    float3x3 S = float3x3(1.0f);
    S[0][0] = exp(scale.x);
    S[1][1] = exp(scale.y);
    S[2][2] = exp(scale.z);
    
    // Normalize quaternion to get valid rotation
    float4 q = rot;// / glm::length(rot);
    float r = q.x;
    float x = q.y;
    float y = q.z;
    float z = q.w;
    
    // Compute rotation matrix from quaternion
    float3x3 R = float3x3(
                          {1.f - 2.f * (y * y + z * z), 2.f * (x * y - r * z), 2.f * (x * z + r * y)},
                          {2.f * (x * y + r * z), 1.f - 2.f * (x * x + z * z), 2.f * (y * z - r * x)},
                          {2.f * (x * z - r * y), 2.f * (y * z + r * x), 1.f - 2.f * (x * x + y * y)}
                          );
    
    float3x3 M = S * R;
    
    // Compute 3D world covariance matrix Sigma
    float3x3 Sigma = transpose(M) * M;
    
    return Sigma;
}

float3 computeCov2D(float3x3 cov3D, float4 t, float4x4 view, float2 focal) {
    float3x3 W = transpose(float3x3({view[0][0], view[0][1], view[0][2]},
                                    {view[1][0], view[1][1], view[1][2]},
                                    {view[2][0], view[2][1], view[2][2]}));
    float3x3 J = float3x3(
                          {focal.x / t.z, 0., -(focal.x * t.x) / (t.z * t.z)},
                          {0., -focal.y / t.z, (focal.y * t.y) / (t.z * t.z)},
                          {0., 0., 0.}
                          );
    float3x3 T = W * J;
    float3x3 Vrk = cov3D;
    
    float3x3 cov = transpose(T) * transpose(Vrk) * T;
    
    // Apply low-pass filter: every Gaussian should be at least
    // one pixel wide/high. Discard 3rd row and column.
    cov[0][0] += 0.3f;
    cov[1][1] += 0.3f;
    return float3(cov[0][0], cov[0][1], cov[1][1]);
}


struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 offsetFromCenter;
    float3 conic;
    float viewZ;
};

vertex VertexOut vertexShader(const device Vertex *vertexArray [[buffer(0)]],
                              constant Gaussian *instanceArray [[buffer(1)]],
                              constant float4x4 &viewMatrix [[buffer(2)]],
                              constant float4x4 &projectionMatrix [[buffer(3)]],
                              constant float2 &focal [[buffer(4)]],
                              constant float2 &viewport [[buffer(5)]],
                              constant zItem *zBuffer [[buffer(6)]],
                              constant float3 &camPos [[buffer(7)]],
                              unsigned int vid [[vertex_id]],
                              unsigned int iid [[instance_id]]) {
    float3 quadVertex = vertexArray[vid].position;
    Gaussian instance = instanceArray[zBuffer[iid].index];
    VertexOut output;
    
    float3 mean = float3(instance.x, instance.y, instance.z);
    float4 t = viewMatrix * float4(mean, 1.0f);
    t = float4(t.x / t.w, t.y / t.w, t.z / t.w, 1.0);
    output.viewZ = t.z;
    
    float tan_fovx = viewport.x / (2.0 * focal.x);
    float tan_fovy = viewport.y / (2.0 * focal.y);
    float limx = 1.3f * tan_fovx;
    float limy = 1.3f * tan_fovy;
    float txtz = t.x / t.z;
    float tytz = t.y / t.z;
    float tx = min(limx, max(-limx, txtz)) * t.z;
    float ty = min(limy, max(-limy, tytz)) * t.z;
    
    float3 scale = float3(instance.scale_0, instance.scale_1, instance.scale_2);
    float4 rot = float4(instance.rot_0, instance.rot_1, instance.rot_2, instance.rot_3);
    float3x3 cov3D = computeCov3D(scale, rot);
    float3 cov2D = computeCov2D(cov3D, float4(tx, ty, t.z, t.w), viewMatrix, focal);
    
    // Compute extent in screen space (by finding eigenvalues of
    // 2D covariance matrix). Use extent to compute a bounding rectangle
    
    // Adapted from https://github.com/antimatter15/splat
    float diagonal1 = cov2D.x;
    float offDiagonal = cov2D.y;
    float diagonal2 = cov2D.z;
    
    float mid = 0.5 * (diagonal1 + diagonal2);
    float radius = length(float2((diagonal1 - diagonal2) / 2.0, offDiagonal));
    float lambda1 = mid + radius;
    float lambda2 = max(mid - radius, 0.1);
    
    float2 diagonalVector = normalize(float2(offDiagonal, lambda1 - diagonal1));
    float2 v1 = min(sqrt(2.0 * lambda1), 1024.0) * diagonalVector;
    float2 v2 = min(sqrt(2.0 * lambda2), 1024.0) * float2(diagonalVector.y, -diagonalVector.x);
    
    output.offsetFromCenter = float2(quadVertex[0], quadVertex[1]);
    
    float4 tt = projectionMatrix * t;
    float bounds = 1.2 * tt.w;
    if (tt.z < -tt.w
        || tt.x < -bounds
        || tt.x > bounds
        || tt.y < -bounds
        || tt.y > bounds) {
        output.position = float4(0.0, 0.0, 2.0, 1.0);
        return output;
    }
    output.position = tt / tt.w;
    output.position.xy += quadVertex.x * v1 * 2.0 / viewport + quadVertex.y * v2 * 2.0 / viewport;
    output.position.w = 1.0;
    float alpha = 1.0 / (1.0 + exp(-instance.opacity));
    float3 dir = normalize(mean - camPos);
    output.color = float4(computeColorFromSH(instance, 0, dir), alpha);
    return output;
}

fragment float4 fragmentShader(VertexOut input [[stage_in]]) {
    float A = -dot(input.offsetFromCenter, input.offsetFromCenter);
    if (A < -4.0) discard_fragment();
    float B = exp(A) * input.color.a;
    float4 color = float4(B * input.color.rgb, B);
    
    return color;
}

kernel void computeZBuffer(device zItem *zBuffer [[buffer(0)]],
                           device atomic_uint &inFrustum [[buffer(1)]],
                           constant Gaussian *instances [[buffer(2)]],
                           constant float4x4 &viewMatrix [[buffer(3)]],
                           constant float4x4 &projectionMatrix [[buffer(4)]],
                           uint i [[thread_position_in_grid]]) {
    Gaussian instance = instances[i];
    float3 mean = float3(instance.x, instance.y, instance.z);
    float4 t = viewMatrix * float4(mean, 1.0f);
    float4 tt = projectionMatrix * t;
    tt /= tt.w;
    if (abs(tt.x) <= 1 && abs(tt.y) <= 1 && tt.z >= 0 && tt.z <= 1) {
        uint index = atomic_fetch_add_explicit(&inFrustum, 1, memory_order_relaxed);
        zBuffer[index].index = i;
        zBuffer[index].z = t.z * 16184;
    }
}

kernel void bitonicSort(device zItem *zBuffer [[buffer(0)]],
                        constant uint &k [[buffer(1)]],
                        constant uint &j [[buffer(2)]],
                        constant uint &logJ [[buffer(3)]],
                        uint i [[thread_position_in_grid]]) {
    uint l = i ^ j;
    bool dir = (i & k) == 0;
    bool swap = (l > i) && (dir && zBuffer[i].z > zBuffer[l].z || !dir && (zBuffer[i].z < zBuffer[l].z));
    if (swap) {
        zItem t = zBuffer[i];
        zBuffer[i] = zBuffer[l];
        zBuffer[l] = t;
    }
}

kernel void bitonicSortThreadGroup(device zItem *zBuffer [[buffer(0)]],
                        constant uint &k [[buffer(1)]],
                        constant uint &jStart [[buffer(2)]],
                        threadgroup zItem *localZBuffer [[threadgroup(0)]],
                        uint i [[thread_position_in_grid]],
                        uint threadGroupId [[threadgroup_position_in_grid]],
                        uint threadGroupSize [[threads_per_threadgroup]],
                        uint iLoc [[thread_position_in_threadgroup]]) {
    localZBuffer[iLoc] = zBuffer[i];
    threadgroup_barrier(mem_flags::mem_threadgroup);
    bool dir = (i & k) == 0;
    for (uint j = jStart; j > 0; j >>= 1) {
        uint l = i ^ j;
        uint lLoc = l & (threadGroupSize - 1);
        if ((l > i) && (dir && localZBuffer[iLoc].z > localZBuffer[lLoc].z || !dir && (localZBuffer[iLoc].z < localZBuffer[lLoc].z))) {
            zItem t = localZBuffer[iLoc];
            localZBuffer[iLoc] = localZBuffer[lLoc];
            localZBuffer[lLoc] = t;
        }
        threadgroup_barrier(mem_flags::mem_none);
    }
    zBuffer[i] = localZBuffer[iLoc];
}
