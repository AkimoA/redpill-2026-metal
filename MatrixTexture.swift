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

// This code encapsulates all the ugly details of loading a texture from a graphics file
// into allocated memory, and converting it into the format needed by Metal.

@objc(MatrixTexture)
public class MatrixTexture: NSObject {

    // Metal device used to create the texture
    private let device: MTLDevice

    // Size of texture (height and width)
    private var width = 0
    private var height = 0

    // Raw data, tightly packed RGBA, rows flipped top to bottom
    private var data: [UInt8] = []

    // The Metal texture used to refer to the glyphs
    private var texture: MTLTexture?

    // Has the texture data been successfully loaded?
    private var fileWasLoaded: Bool = false

    init(withDevice device: MTLDevice) {
        self.device = device
        super.init()
    }

    // Accessor method for the Metal texture
    var mtltexture: MTLTexture? {
        return texture
    }

    // Accessor method for whether the file has been loaded successfully yet
    var fileLoaded: Bool {
        return fileWasLoaded
    }

    // Load bitmap data from a file.
    private func loadBitmap(_ filename: String) -> Bool {
        // Load image file
        let url = URL(fileURLWithPath: filename)
        guard let imageData = try? Data(contentsOf: url),
              let img = NSBitmapImageRep(data: imageData) else {
            logError("loadBitmap", note: "Failed to load image data. Image file is broken?")
            return false
        }

        // Work out format
        let depth = img.samplesPerPixel
        let rowsize = img.bytesPerRow
        guard depth == 3 || depth == 4 else {
            logError("loadBitmap", note: "unrecognized bitmap format.")
            return false
        }
        let pixelStride = max(depth, img.bitsPerPixel / 8)

        let w = img.pixelsWide
        let h = img.pixelsHigh
        guard w > 0, h > 0, let imgdata = img.bitmapData else {
            logError("loadBitmap", note: "Image has no bitmap data.")
            return false
        }

        // Copy the image into the texture bitmap, flipping the rows top to bottom.
        // If the image has no alpha channel (RGB), create an alpha channel from the pixel
        // brightness. This assumes the image is colored letters on black background.
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        for row in 0..<h {
            let src = imgdata + row * rowsize
            let destrow = h - 1 - row
            for col in 0..<w {
                let p = src + col * pixelStride
                let o = (destrow * w + col) * 4
                rgba[o] = p[0]
                rgba[o + 1] = p[1]
                rgba[o + 2] = p[2]
                if depth == 4 {
                    rgba[o + 3] = p[3]
                } else {
                    let brightness = (Int(p[0]) + Int(p[1]) + Int(p[2])) / 3
                    rgba[o + 3] = brightness > 10 ? 255 : 0  // Threshold for visibility
                }
            }
        }

        width = w
        height = h
        data = rgba
        fileWasLoaded = true
        return true
    }

    // Load bitmap data from a file, using the above method, then create a Metal texture from it.
    func loadFromFile(_ filename: String) -> Bool {
        // Work out full path to image file
        // Extract the name and extension from the filename
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension.isEmpty ? "png" : (filename as NSString).pathExtension

        guard let imagePath = Bundle(for: type(of: self)).path(forResource: name, ofType: ext) else {
            logError("loadFromFile", note: "Could not find \(filename) in bundle resources")
            return false
        }

        // See if it exists
        guard FileManager.default.fileExists(atPath: imagePath) else {
            logError("loadFromFile", note: "\(filename) does not exist at expected path: \(imagePath)")
            return false
        }

        guard loadBitmap(imagePath) else {
            logError("loadFromFile", note: "loadFromFile failed to load bitmap.")
            return false
        }

        // Now create a Metal texture.
        // Bilinear filtering and clamp-to-edge addressing are set up in the shader's sampler.
        // The texture is RGBA, quads are modulated by it into letters of whatever color.
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = .shaderRead

        guard let newTexture = device.makeTexture(descriptor: descriptor) else {
            logError("loadFromFile", note: "Failed to create Metal texture")
            fileWasLoaded = false
            return false
        }

        data.withUnsafeBytes { bytes in
            if let base = bytes.baseAddress {
                newTexture.replace(
                    region: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0,
                    withBytes: base,
                    bytesPerRow: width * 4
                )
            }
        }

        texture = newTexture
        data = []
        return true
    }
}
