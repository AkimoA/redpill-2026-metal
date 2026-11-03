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

import Foundation

// Some useful constants used in various places in the code

// Random float from 0.0 to 1.0
func randomFloat01() -> Float {
    return Float(arc4random_uniform(100)) / 100.0
}

// Random float from -1.0 to 1.0
func randomFloat11() -> Float {
    return Float(arc4random_uniform(200)) / 100.0 - 1.0
}

// Assorted constants

// Near and far clipping planes, cm from the user's eye
let clipNear: Double = 40.0
let clipFar: Double = 250.0

// Field of view in degrees
let fieldOfView: Double = 45.0
// Needed for correct calculation of fov
let pi: Double = 3.1415926535897932384626433832795
// Tangent of half that value, used for calculating coordinate ranges
let tanFov: Double = 0.4142

// Integer number of glyphs in the texture pixmap
// The pixmap is an 8x8 grid, glyph 0 = top left, and should be empty space
// Each square of the grid is 32x32 and contains one glyph
// Not all squares need to be filled
let numGlyphs: Int = 64

// Cell size in cm
// Bear in mind that it needs to be visible when CLIP_FAR away, each cell holds one glyph
let cellSize: Double = 1.0

// Cell spacing in strips is multiplied by this, to pull them apart a bit
let quadSquishFactor: Double = 1.02