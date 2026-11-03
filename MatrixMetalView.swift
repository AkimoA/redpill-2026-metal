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

// This class replaces MatrixOpenGLView. It is a layer-hosting view whose layer is a
// CAMetalLayer. All drawing is driven by the main screensaver class (MatrixView),
// which has ready access to the strips, preferences, and so on.

final class MatrixMetalView: NSView {

    private let metal = CAMetalLayer()

    var metalLayer: CAMetalLayer {
        return metal
    }

    init(frame: NSRect, device: MTLDevice) {
        super.init(frame: frame)
        metal.device = device
        metal.pixelFormat = .bgra8Unorm
        metal.framebufferOnly = true
        metal.isOpaque = true
        metal.backgroundColor = NSColor.black.cgColor
        layer = metal
        wantsLayer = true
        updateDrawableSize()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Keep the drawable at the native pixel size of the view
    private func updateDrawableSize() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0
        metal.contentsScale = scale
        metal.drawableSize = CGSize(
            width: max(1.0, (bounds.width * scale).rounded()),
            height: max(1.0, (bounds.height * scale).rounded())
        )
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSize()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateDrawableSize()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize()
    }
}
