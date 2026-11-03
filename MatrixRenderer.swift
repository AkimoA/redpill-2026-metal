// This file is part of Red Pill
// A 3D Metal "Matrix" screensaver for Mac OS X
// Copyright (C) 2002, 2003 mathew <meta@pobox.com>
// Copyright (C) 2016 px3 <rr@rdsroot.net>
// Copyright (C) 2025 AkimoA
//
// Red Pill is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
// or visit <URL:http://www.fsf.org/>

import Cocoa
import Metal
import QuartzCore
import simd

// Uniforms shared with MatrixShaders.metal - the layout must match MatrixUniforms there
private struct MatrixUniforms {
    var projection: simd_float4x4
    var fogStart: Float
    var fogEnd: Float
    var fogEnabled: UInt32
    var padding: UInt32 = 0
}

// This class owns the Metal state: command queue, pipeline, per-frame vertex buffers and
// the projection matrix. It replaces the OpenGL context state set up in initGL/resizeGL.

@MainActor
final class MatrixRenderer {

    let device: MTLDevice

    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    // Triple buffered vertex data, rewritten from the strips every frame
    private static let bufferCount = 3
    private var vertexBuffers: [MTLBuffer?] = [nil, nil, nil]
    private var frameIndex = 0
    private let inFlight = DispatchSemaphore(value: MatrixRenderer.bufferCount)

    private var projection = matrix_identity_float4x4

    init?(device: MTLDevice, bundle: Bundle) {
        guard let queue = device.makeCommandQueue() else {
            logError("MatrixRenderer.init", note: "Failed to create Metal command queue.")
            return nil
        }

        let library: MTLLibrary
        do {
            library = try device.makeDefaultLibrary(bundle: bundle)
        } catch {
            logError("MatrixRenderer.init", note: "Failed to load Metal shader library: \(error)")
            return nil
        }

        guard let vertexFunction = library.makeFunction(name: "matrixVertex"),
              let fragmentFunction = library.makeFunction(name: "matrixFragment") else {
            logError("MatrixRenderer.init", note: "Failed to find shader functions.")
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction

        let attachment: MTLRenderPipelineColorAttachmentDescriptor = descriptor.colorAttachments[0]
        attachment.pixelFormat = .bgra8Unorm
        // glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        attachment.isBlendingEnabled = true
        attachment.rgbBlendOperation = .add
        attachment.alphaBlendOperation = .add
        attachment.sourceRGBBlendFactor = .sourceAlpha
        attachment.sourceAlphaBlendFactor = .sourceAlpha
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        let pipeline: MTLRenderPipelineState
        do {
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            logError("MatrixRenderer.init", note: "Failed to create pipeline state: \(error)")
            return nil
        }

        self.device = device
        self.commandQueue = queue
        self.pipelineState = pipeline
    }

    // Set up the projection for the given aspect ratio (was resizeGL)
    func setAspectRatio(_ aspectRatio: Float) {
        // 45 degrees FOV = 50mm lens on a 35mm camera, should look natural
        // Same as GLKMatrix4MakePerspective, but with Metal's 0...1 clip space depth
        let near = Float(clipNear)
        let far = Float(clipFar * 1.2)
        let fovy = Float(fieldOfView * pi / 180.0)
        let f = 1.0 / tanf(fovy / 2.0)
        let a = far / (near - far)
        let b = far * near / (near - far)
        projection = simd_float4x4(columns: (
            SIMD4<Float>(f / aspectRatio, 0, 0, 0),
            SIMD4<Float>(0, f, 0, 0),
            SIMD4<Float>(0, 0, a, -1),
            SIMD4<Float>(0, 0, b, 0)
        ))
    }

    // Wait until the GPU has finished all frames in flight
    func waitUntilIdle() {
        for _ in 0..<MatrixRenderer.bufferCount {
            inFlight.wait()
        }
        for _ in 0..<MatrixRenderer.bufferCount {
            inFlight.signal()
        }
    }

    // Clear to black, draw all the strips (back to front, in array order), present
    func render(layer: CAMetalLayer, strips: [MatrixStrip], glyphs: MTLTexture?, fogEnabled: Bool) {
        let size = layer.drawableSize
        guard size.width >= 1, size.height >= 1 else {
            return
        }
        guard let drawable = layer.nextDrawable() else {
            return
        }

        inFlight.wait()

        // Fill the vertex buffer from the strips
        var quadCount = 0
        var vertexBuffer: MTLBuffer?
        if glyphs != nil && !strips.isEmpty {
            var quadBudget = 0
            for strip in strips {
                quadBudget += strip.maxQuadsPerDraw
            }
            let bytesPerQuad = 4 * MatrixStrip.floatsPerVertex * MemoryLayout<Float>.stride
            let needed = quadBudget * bytesPerQuad

            if let existing = vertexBuffers[frameIndex], existing.length >= needed {
                vertexBuffer = existing
            } else {
                vertexBuffer = device.makeBuffer(length: max(needed + needed / 2, 65536), options: .storageModeShared)
                vertexBuffers[frameIndex] = vertexBuffer
            }

            if let buffer = vertexBuffer {
                var cursor = buffer.contents().bindMemory(
                    to: Float.self,
                    capacity: buffer.length / MemoryLayout<Float>.stride
                )
                for strip in strips {
                    let quads = strip.writeQuads(into: cursor)
                    quadCount += quads
                    cursor += quads * 4 * MatrixStrip.floatsPerVertex
                }
            }
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            inFlight.signal()
            return
        }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            inFlight.signal()
            return
        }

        if quadCount > 0, let buffer = vertexBuffer, let glyphs = glyphs {
            var uniforms = MatrixUniforms(
                projection: projection,
                fogStart: Float(clipNear),
                fogEnd: Float(clipFar * 1.2),
                fogEnabled: fogEnabled ? 1 : 0
            )
            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<MatrixUniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MatrixUniforms>.stride, index: 1)
            encoder.setFragmentTexture(glyphs, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadCount * 6)
        }
        encoder.endEncoding()

        commandBuffer.present(drawable)
        let semaphore = inFlight
        commandBuffer.addCompletedHandler { _ in
            semaphore.signal()
        }
        commandBuffer.commit()

        frameIndex = (frameIndex + 1) % MatrixRenderer.bufferCount
    }
}
