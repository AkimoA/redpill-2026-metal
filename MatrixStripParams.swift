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

// The parameters which determine the animation behavior
struct MatrixStripParams {
    var cellSize: Float // size of the quad containing one glyph
    var maxCellLife: Int // max lifetime of a living cell
    var numGlyphs: Int // number of glyphs available in texture
    var cursorChangeProbability: Int // percentage chance of cursor state change during drawing phase
    var cursorLiveProbability: Int // relative amounts of time the cursor spends drawing live cells,
    var cursorStaticProbability: Int // static cells,
    var cursorEmptyProbability: Int // or empty space
    var framesPerLivingCellChange: Int // how many 1/30ths of a second for each living cell to change glyph
    var cursorSpeed: Float // speed of cursor fall
    var maxDepth: Float // depth strips start at
    var minDepth: Float // depth at which strips are clipped away
    var maxStrips: Int // how many do we want?
    var spawnChance: Float // if we don't have enough stuff, what's the probability of adding more stuff
    // this animation frame? Changes to 1.0 after the first strip hits the front...
    var driftSpeed: Float // speed stuff drifts towards us at
    var aspectRatio: Float // we need this to work out when a strip falls off the sides of the visible area
    var minStartY: Float // 1.0 to start at top of screen, 0.0 to start at random point in top half
    var fogDensity: Float // 0 to 0.2, or you won't see anything
    var colorCycleSpeed: Float // color cycling speed
    var colorFallSpeed: Float // rate at which cycling colors fall
}