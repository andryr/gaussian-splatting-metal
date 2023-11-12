//
//  Renderer.swift
//  gaussian-splatting-metal
//
//  Created by Andry Rafaralahy on 11/10/2023.
//

import MetalKit

class Renderer: NSObject, MTKViewDelegate {
    
    var parent: ContentView
    var device: MTLDevice!
    var renderCommandQueue: MTLCommandQueue!
    var library: MTLLibrary!
    var renderPipelineState: MTLRenderPipelineState!
    var computeViewPositionsPipelineState: MTLComputePipelineState!
    var sortPipelineState: MTLComputePipelineState!
    var sortPipelineThreadGroupState: MTLComputePipelineState!
    var pow2size: Int!
    var vertexBuffer: MTLBuffer!
    var instanceBuffer: MTLBuffer!
    var zBuffer: MTLBuffer!
    var inFrustumCounterBuffer: MTLBuffer!
    var gaussians: [Gaussian]!
    var camera: Camera!
    var viewMatrix: simd_float4x4!
    var projectionMatrix: simd_float4x4!
    var viewMatrixBuffer: MTLBuffer!
    var projectionMatrixBuffer: MTLBuffer!
    var sorted = false
    
    init(_ parent: ContentView) {
        self.parent = parent
        super.init()
        
        guard let path = Bundle.main.path(forResource: "point_cloud", ofType: "ply") else {
            fatalError("Could not find ply file")
        }
        let reader = PlyFileReader(URL(fileURLWithPath: path))
        reader.readHeader()
        gaussians = reader.readGaussians()
        
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.device = metalDevice
        }
        renderCommandQueue = device.makeCommandQueue()
        library = device.makeDefaultLibrary()!
        
        initInstanceBuffer()
        initVertexBuffer()
        initComputeViewPositionsPipelineState()
        initSortPipelineState()
        initSortPipelineThreadGroupState()
        initRenderPipeline()
        
        camera = Camera(width: 4946, height: 3286,
                             position: [ -0.04774771700919393,
                                          1.3736281210574213,
                                          -3.791160728184646],
                             rot0: [  0.9823201700242411,
                                      -0.012188056404746963,
                                      0.18681149548307044],
                             rot1: [  0.03363250900107312,
                                      0.9931324589140686,
                                      -0.11205700955133846],
                             rot2: [ -0.18416280270955715,
                                      0.11635879997821706,
                                      0.9759839608137986],
                             fx: 4627.300372546341, fy: 4649.505977743847)
        
        updateViewMatrix()
        
        initProjectionMatrix()
    }
    
    private func initRenderPipeline() {
        let renderPipelineDesc = MTLRenderPipelineDescriptor()
        renderPipelineDesc.label = "Render Pipeline"
        renderPipelineDesc.vertexFunction = library.makeFunction(name: "vertexShader")
        renderPipelineDesc.fragmentFunction = library.makeFunction(name: "fragmentShader")
        renderPipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineDesc.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .oneMinusDestinationAlpha
        renderPipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .one
        renderPipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .oneMinusDestinationAlpha
        renderPipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .one
        renderPipelineDesc.colorAttachments[0].rgbBlendOperation = .add
        renderPipelineDesc.colorAttachments[0].alphaBlendOperation = .add
        
        do {
            try renderPipelineState = device.makeRenderPipelineState(descriptor: renderPipelineDesc)
        } catch {
            print("Unexpected error \(error)")
            fatalError()
        }
    }
    
    private func initComputeViewPositionsPipelineState() {
        do {
            try computeViewPositionsPipelineState = device.makeComputePipelineState(function: library.makeFunction(name: "computeZBuffer")!)
        } catch {
            print("Unexpected error \(error)")
            fatalError()
        }
    }
    
    private func initSortPipelineState() {
        do {
            try sortPipelineState = device.makeComputePipelineState(function: library.makeFunction(name: "bitonicSort")!)
        } catch {
            print("Unexpected error \(error)")
            fatalError()
        }
    }
    
    private func initSortPipelineThreadGroupState() {
        do {
            try sortPipelineThreadGroupState = device.makeComputePipelineState(function: library.makeFunction(name: "bitonicSortThreadGroup")!)
        } catch {
            print("Unexpected error \(error)")
            fatalError()
        }
    }
    
    
    private func initInstanceBuffer() {
        pow2size = 1 << Int(ceil(log2f(Float(gaussians.count))))
        instanceBuffer = device.makeBuffer(bytes: gaussians, length: gaussians.count * MemoryLayout<Gaussian>.stride, options: [])!
        zBuffer = device.makeBuffer(length: pow2size * MemoryLayout<zItem>.stride, options: [])
        clearZBuffer()
        inFrustumCounterBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: [])
    }
    
    private func clearZBuffer() {
        let zBufferContents = zBuffer.contents()
        zBufferContents.initializeMemory(as: zItem.self, repeating: zItem(index: 0, z: Int32.max), count: pow2size)
    }
    
    private func initVertexBuffer() {
        let vertices = [
            Vertex(position: [-2.0, -2.0, 0.0]),
            Vertex(position: [2.0, -2.0, 0.0]),
            Vertex(position: [2.0, 2.0, 0.0]),
            Vertex(position: [2.0, 2.0, 0.0]),
            Vertex(position: [-2.0, 2.0, 0.0]),
            Vertex(position: [-2.0, -2.0, 0.0]),
        ]
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if let mv = view as? MetalView {
            mv.onKeyDown(eventCallback: {
                [weak self] event in
                if (event.characters == "w") {
                    self?.goForward()
                    view.draw()
                } else if (event.characters == "s") {
                    self?.goBackward()
                    view.draw()
                } else if (event.characters == "d") {
                    self?.goRight()
                    view.draw()
                } else if (event.characters == "a") {
                    self?.goLeft()
                    view.draw()
                } else if (event.characters == "x") {
                    self?.resetToHorizontal()
                    view.draw()
                }
            }).onMouseDragged(eventCallback: {
                [weak self] event in
                let deltaX = event.deltaX
                let deltaY = event.deltaY
                self?.rotateCamera(deltaX: Float(deltaX), deltaY: Float(deltaY))
                view.draw()
            })
        }
    }
    
    private func updateViewMatrix() {
        viewMatrix = simd_float4x4(
            [camera.rot0[0], camera.rot0[1], camera.rot0[2], 0],
            [camera.rot1[0], camera.rot1[1], camera.rot1[2], 0],
            [camera.rot2[0], camera.rot2[1], camera.rot2[2], 0],
            [-camera.position.x * camera.rot0[0] - camera.position.y * camera.rot1[0] - camera.position.z * camera.rot2[0],
              -camera.position.x * camera.rot0[1] - camera.position.y * camera.rot1[1] - camera.position.z * camera.rot2[1],
              -camera.position.x * camera.rot0[2] - camera.position.y * camera.rot1[2] - camera.position.z * camera.rot2[2],
              1]
        )
        viewMatrixBuffer = device.makeBuffer(bytes: &viewMatrix, length: MemoryLayout.size(ofValue: viewMatrix), options: [])!
    }
    
    private func initProjectionMatrix() {
        let zNear: Float = 0.2
        let zFar: Float = 200.0
        let dz = zFar - zNear
        // Adjust projection matrix to work with Metal NDC system (see https://metashapes.com/blog/opengl-metal-projection-matrix-problem/)
        var adjust = simd_float4x4(1.0)
        adjust[2][2] = 0.5
        adjust[3][2] = 0.5
        projectionMatrix =  adjust * simd_float4x4(
            [2.0 * camera.fx / Float(camera.width), 0.0, 0.0, 0.0],
            [0.0, -2.0 * camera.fy / Float(camera.height), 0.0, 0.0],
            [0.0, 0.0, zFar / dz, 1.0],
            [0.0, 0.0, -zFar * zNear / dz, 0.0]
        )
        projectionMatrixBuffer = device.makeBuffer(bytes: &projectionMatrix, length: MemoryLayout.size(ofValue: projectionMatrix), options: [])!
    
    }
    
    private func goForward() {
        camera.position += 0.1 * camera.getDirection()
        updateViewMatrix()
    }
    
    private func goBackward() {
        camera.position -= 0.1 * camera.getDirection()
        updateViewMatrix()
    }
    
    private func goRight() {
        camera.position += 0.1 * camera.getRight()
        updateViewMatrix()
    }
    
    private func goLeft() {
        camera.position -= 0.1 * camera.getRight()
        updateViewMatrix()
    }
    
    private func rotateCamera(deltaX: Float, deltaY: Float) {
        let xAngle = deltaX / 200.0 * Float.pi
        let yAngle = -deltaY / 400.0 * Float.pi

        camera.rotateDirectionVectorAroundUp(angle: xAngle)
        camera.rotateDirectionVectorAroundRight(angle: yAngle)
        
        updateViewMatrix()
    }
    
    private func resetToHorizontal() {
        camera.resetToHorizontal()
        updateViewMatrix()
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else {
            return
        }
        
        let start = Date()

        let renderCommandBuffer = renderCommandQueue.makeCommandBuffer()!
        computeViewPositions(commandQueue: renderCommandQueue)
        
        sortInstances(commandBuffer: renderCommandBuffer)
        
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        drawInstances(commandBuffer: renderCommandBuffer, renderPassDescriptor: renderPassDescriptor)
        
        renderCommandBuffer.present(drawable)
        renderCommandBuffer.commit()
        
        renderCommandBuffer.waitUntilCompleted()
        let end = Date()
        let diff = start.distance(to: end)
        print("Render time \(diff), fps: \(1/diff)")
    }
    
    private func computeViewPositions(commandQueue: MTLCommandQueue) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        clearZBuffer()
        let grid_size = MTLSizeMake(gaussians.count, 1, 1)
        let unit_size = min(grid_size.width, computeViewPositionsPipelineState.maxTotalThreadsPerThreadgroup)
        let group_size = MTLSizeMake(unit_size, 1, 1)
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        commandEncoder.pushDebugGroup("Compute view positions")
        commandEncoder.setComputePipelineState(computeViewPositionsPipelineState)
        commandEncoder.setBuffer(zBuffer, offset: 0, index: 0)
        inFrustumCounterBuffer.contents().initializeMemory(as: UInt32.self, to: UInt32(0))
        commandEncoder.setBuffer(inFrustumCounterBuffer, offset: 0, index: 1)
        commandEncoder.setBuffer(instanceBuffer, offset: 0, index: 2)
        commandEncoder.setBuffer(viewMatrixBuffer, offset: 0, index: 3)
        commandEncoder.setBuffer(projectionMatrixBuffer, offset: 0, index: 4)
        commandEncoder.dispatchThreads(grid_size, threadsPerThreadgroup: group_size)
        commandEncoder.popDebugGroup()
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    private func sortInstances(commandBuffer: MTLCommandBuffer) {
        let inFrustum: UInt32 = inFrustumCounterBuffer.contents().load(as: UInt32.self)
        let pow2size = 1 << Int(ceil(log2f(Float(inFrustum))))
        let threadsPerGroup = MTLSize(width: sortPipelineState.maxTotalThreadsPerThreadgroup, height: 1, depth: 1)
        let numThreadGroups = MTLSize(width: pow2size / threadsPerGroup.width, height: 1, depth: 1)
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        commandEncoder.setBuffer(zBuffer, offset: 0, index: 0)
        var k = 2
        while k <= pow2size {
            var kk = UInt32(k)
            commandEncoder.setBytes(&kk, length: MemoryLayout<UInt32>.stride, index: 1)
            var j = k / 2
            while j > 0 {
                var jj = UInt32(j)
                commandEncoder.setBytes(&jj, length: MemoryLayout<UInt32>.stride, index: 2)
                
                if (2 * j <= threadsPerGroup.width) {
                    commandEncoder.setComputePipelineState(sortPipelineThreadGroupState)
                    commandEncoder.setThreadgroupMemoryLength(MemoryLayout<zItem>.stride * threadsPerGroup.width, index: 0)
                    j = 0
                } else {
                    commandEncoder.setComputePipelineState(sortPipelineState)
                    var logJ = jj.trailingZeroBitCount
                    commandEncoder.setBytes(&logJ, length: MemoryLayout<UInt32>.stride, index: 3)
                }

                commandEncoder.dispatchThreadgroups(numThreadGroups, threadsPerThreadgroup: threadsPerGroup)
                j /= 2
            }
            k *= 2
        }
        commandEncoder.endEncoding()
    }
    
    private func drawInstances(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderEncoder.pushDebugGroup("Instance Rendering")
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(instanceBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(viewMatrixBuffer, offset: 0, index: 2)
        renderEncoder.setVertexBuffer(projectionMatrixBuffer, offset: 0, index: 3)
        var focal = simd_float2(camera.fx, camera.fy)
        let focalBuffer = device.makeBuffer(bytes: &focal, length: MemoryLayout.size(ofValue: focal), options: [])!
        renderEncoder.setVertexBuffer(focalBuffer, offset: 0, index: 4)
        var viewport = simd_float2(Float(camera.width), Float(camera.height))
        let viewportBuffer = device.makeBuffer(bytes: &viewport, length: MemoryLayout.size(ofValue: viewport), options: [])!
        renderEncoder.setVertexBuffer(viewportBuffer, offset: 0, index: 5)
        renderEncoder.setVertexBuffer(zBuffer, offset: 0, index: 6)
        var camPos = simd_float3(camera.position)
        renderEncoder.setVertexBytes(&camPos, length: MemoryLayout<simd_float3>.stride, index: 7)
        let inFrustum: UInt32 = inFrustumCounterBuffer.contents().load(as: UInt32.self)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: Int(inFrustum))
        
        renderEncoder.popDebugGroup()
        
        renderEncoder.endEncoding()
    }
}
