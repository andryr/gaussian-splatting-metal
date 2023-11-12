//
//  Camera.swift
//  gaussian-splatting-metal
//
//  Created by Andry Rafaralahy on 29/10/2023.
//

import Foundation


class Camera {
    var width: Int
    var height: Int
    var position: simd_float3
    var rot0: simd_float3
    var rot1: simd_float3
    var rot2: simd_float3
    var fx: Float
    var fy: Float

    init(width: Int, height: Int, position: simd_float3, rot0: simd_float3, rot1: simd_float3, rot2: simd_float3, fx: Float, fy: Float) {
        self.width = width
        self.height = height
        self.position = position
        self.rot0 = rot0
        self.rot1 = rot1
        self.rot2 = rot2
        self.fx = fx
        self.fy = fy
    }

    func getRight() -> simd_float3 {
        return normalize(simd_float3(rot0[0], rot1[0], rot2[0]))
    }
    
    func getUp() -> simd_float3 {
        return normalize(simd_float3(rot0[1], rot1[1], rot2[1]))
    }
    
    func getDirection() -> simd_float3 {
        return normalize(simd_float3(rot0[2], rot1[2], rot2[2]))
    }
    
    func rotateDirectionVectorAroundUp(angle: Float) {
        let right = getRight()
        let up = getUp()
        let direction = getDirection()
        
        let P = simd_float3x3(right, up, direction)
        
        let rotationMatrix = simd_float3x3([cos(angle), 0.0, -sin(angle)],
                                           [0.0, 1.0, 0.0],
                                           [sin(angle), 0.0, cos(angle)])
        
        var newRight = P * rotationMatrix * P.transpose * right;
        newRight.y = 0.0
        newRight = normalize(newRight)
        let newDirection = cross(newRight, up)
        let newUp = cross(newDirection, newRight)
        
        rot0[0] = newRight.x
        rot1[0] = newRight.y
        rot2[0] = newRight.z
        rot0[1] = newUp.x
        rot1[1] = newUp.y
        rot2[1] = newUp.z
        rot0[2] = newDirection.x
        rot1[2] = newDirection.y
        rot2[2] = newDirection.z
    }
    
    func rotateDirectionVectorAroundRight(angle: Float) {
        let right = getRight()
        let up = getUp()
        let direction = getDirection()
        
        let P = simd_float3x3(right, up, direction)
        
        let rotationMatrix = simd_float3x3([1.0, 0.0, 0.0],
                                           [0.0, cos(angle), sin(angle)],
                                           [0.0, -sin(angle), cos(angle)])
        
        let newDirection = P * rotationMatrix * P.transpose * direction;
        let newRight = cross(up, newDirection)
        let newUp = cross(newDirection, newRight)
        
        rot0[0] = newRight.x
        rot1[0] = newRight.y
        rot2[0] = newRight.z
        rot0[1] = newUp.x
        rot1[1] = newUp.y
        rot2[1] = newUp.z
        rot0[2] = newDirection.x
        rot1[2] = newDirection.y
        rot2[2] = newDirection.z
    }
    
    func resetToHorizontal() {
        let newUp = simd_float3([0.0, 1.0, 0.0])
        let direction = getDirection()
        let newDirection = normalize(simd_float3([direction.x, 0.0, direction.z]));
        let newRight = cross(newUp, newDirection)
        
        rot0[0] = newRight.x
        rot1[0] = newRight.y
        rot2[0] = newRight.z
        rot0[1] = newUp.x
        rot1[1] = newUp.y
        rot2[1] = newUp.z
        rot0[2] = newDirection.x
        rot1[2] = newDirection.y
        rot2[2] = newDirection.z
    }
}
