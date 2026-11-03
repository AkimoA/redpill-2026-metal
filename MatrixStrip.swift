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

// MatrixStrip implements a single "particle" object consisting of a strip of
// animated "Matrix code" style glyphs
@objc(MatrixStrip)
public class MatrixStrip: NSObject {
    
    // Internal state variables
    // Location of strip
    private var myX: Float = 0.0
    private var myY: Float = 0.0
    private var myZ: Float = 0.0
    
    // Position of the cursor which writes/erases glyphs, as a cell number
    private var cursorPos: Int = 0
    
    // Offset upwards from 0.0 to 1.0 of a cell, to allow for motion slower than 1 cell per animation frame
    private var cursorOffset: Float = 0.0
    
    // State the cursor writes when writing
    private var cursorState: Int = 0
    
    // Whether the cursor is drawing or erasing
    private var cursorDrawing: Bool = false
    
    // The cursor glyph
    private var cursorGlyph: Int = 0
    
    // Number of cells in strip
    private var stripSize: Int = 0
    
    // Array of cell states
    private var cellState: [Int] = []
    
    // Array of glyphs in cells
    private var cellContents: [Int] = []
    
    // Array of texture coordinates for the vertex buffer
    private var textureArray: [Float] = []
    
    // Array of quad vertices for the vertex buffer
    private var quadArray: [Float] = []
    
    // Array of color vertices for the vertex buffer
    private var colorArray: [Float] = []
    
    // The tweakable parameters which alter the behavior of the strip
    private var stripParams: MatrixStripParams = MatrixStripParams(
        cellSize: 0.0,
        maxCellLife: 0,
        numGlyphs: 0,
        cursorChangeProbability: 0,
        cursorLiveProbability: 0,
        cursorStaticProbability: 0,
        cursorEmptyProbability: 0,
        framesPerLivingCellChange: 0,
        cursorSpeed: 0.0,
        maxDepth: 0.0,
        minDepth: 0.0,
        maxStrips: 0,
        spawnChance: 0.0,
        driftSpeed: 0.0,
        aspectRatio: 0.0,
        minStartY: 0.0,
        fogDensity: 0.0,
        colorCycleSpeed: 0.0,
        colorFallSpeed: 0.0
    )
    
    // Internal counter used to reduce the animation speed of living cells
    private var framecounter: Int = 0
    
    // Internal float used to animate the colors
    private var startColor: Float = 0.0
    
    // Ints used to store the first and last visible cells that need to be drawn
    private var firstVisibleCell: Int = 0
    private var lastVisibleCell: Int = 0
    
    // Initialize with top left corner at given position
    init?(withCells cells: Int, x: Float, y: Float, z: Float, params: MatrixStripParams) {
        super.init()
        
        // So far, so good; now allocate storage
        cellState = [Int](repeating: 0, count: cells)
        cellContents = [Int](repeating: 0, count: cells)
        
        // Each cell needs four x,y texture vertex coordinates
        textureArray = [Float](repeating: 0.0, count: cells * 4 * 2)
        // and four x,y,z quad vertex coordinates
        quadArray = [Float](repeating: 0.0, count: cells * 4 * 3)
        // and four r,g,b,a color values
        colorArray = [Float](repeating: 0.0, count: cells * 4 * 4)
        
        // Record how big we are and where
        stripSize = cells
        myX = x
        myY = y
        myZ = z
        
        // Copy/store the behavior parameters
        stripParams = params
        
        // Initialize the cursor
        randomizeCursorState()
        cursorPos = 1
        cursorOffset = 1.0
        cursorDrawing = true
        framecounter = 0
        startColor = 0.2
        randomizeCursorGlyph()
        
        // Initialize cells
        for c in 0..<cells {
            cellState[c] = 0 // Empty
            cellContents[c] = 0 // Space
        }
        
        // Create the strip of quads by creating the arrays needed to draw it
        computeQuadVertices(cells, x: x, y: y, z: z)
        initializeColorVertices(cells)
        initializeTextureVertices(cells)
    }
    
    // Access method
    var z: Float {
        return myZ
    }
    
    // Method to pick a random glyph for the cursor
    private func randomizeCursorGlyph() {
        if cursorDrawing {
            cursorGlyph = 1 + (Int.random(in: 0..<Int(stripParams.numGlyphs - 1)))
        } else {
            cursorGlyph = 0
        }
    }
    
    // Two methods to change the cursor's state between drawing live cells,
    // drawing static cells, and drawing blanks.
    // The first just sets things up from scratch.
    private func randomizeCursorState() {
        randomizeCursorState(-1)
    }
    
    // The second implements a simple state machine.
    private func randomizeCursorState(_ current: Int) {
        if current == 0 {
            // Cursor is drawing empty space
            // Next state is either draw-live or draw-static
            let rand = Int.random(in: 0..<Int(stripParams.cursorLiveProbability + stripParams.cursorStaticProbability))
            cursorState = rand < stripParams.cursorLiveProbability ? (Int.random(in: 0..<stripParams.maxCellLife)) : 1
        } else if current == 1 {
            // Cursor is drawing static cells
            // Next state is either draw-live or draw-empty-space
            let rand = Int.random(in: 0..<Int(stripParams.cursorLiveProbability + stripParams.cursorEmptyProbability))
            cursorState = rand < stripParams.cursorLiveProbability ? (Int.random(in: 0..<stripParams.maxCellLife)) : 0
        } else if current > 1 {
            // Cursor is drawing live cells
            // Next state is either draw-static or draw-empty-space
            let rand = Int.random(in: 0..<Int(stripParams.cursorStaticProbability + stripParams.cursorEmptyProbability))
            cursorState = rand < stripParams.cursorStaticProbability ? 1 : 0
        } else {
            // None of the above
            // Pick a state completely at random
            let x = Int.random(in: 0..<Int(stripParams.cursorStaticProbability + stripParams.cursorEmptyProbability + stripParams.cursorLiveProbability))
            if x < stripParams.cursorEmptyProbability {
                cursorState = 0
            } else if x < (stripParams.cursorEmptyProbability + stripParams.cursorStaticProbability) {
                cursorState = 1
            } else {
                cursorState = Int.random(in: 0..<stripParams.maxCellLife)
            }
        }
    }
    
    // Compute an entire array of quad vertices, given x,y,z of the top left corner
    private func computeQuadVertices(_ cells: Int, x: Float, y: Float, z: Float) {
        let size = stripParams.cellSize
        let minY = Float(Double(z) * tanFov)
        let maxY = -minY
        
        firstVisibleCell = -1
        lastVisibleCell = -1
        
        for i in 0..<cells {
            // Compute bottom y coord of cell
            let by = y - Float(quadSquishFactor) * size * Float(i)
            // Record the first cell that is at least partially on screen
            if ((by < maxY) && (firstVisibleCell == -1)) {
                firstVisibleCell = i
            }
            // and the last
            if (((by + size) < minY) && (lastVisibleCell == -1)) {
                lastVisibleCell = i-1
            }
            // Bottom left vertex
            quadArray[12*i + 0] = x
            quadArray[12*i + 1] = by
            quadArray[12*i + 2] = z
            // Bottom right vertex
            quadArray[12*i + 3] = x + size
            quadArray[12*i + 4] = by
            quadArray[12*i + 5] = z
            // Top right vertex
            quadArray[12*i + 6] = x + size
            quadArray[12*i + 7] = by + size
            quadArray[12*i + 8] = z
            // Top left vertex
            quadArray[12*i + 9] = x
            quadArray[12*i + 10] = by + size
            quadArray[12*i + 11] = z
        }
        // Check for case where all cells are above bottom of screen
        if (lastVisibleCell == -1) {
            lastVisibleCell = cells
        }
    }
    
    // Initialize the array of color vertices
    private func initializeColorVertices(_ maxcell: Int) {
        for i in 0..<(maxcell * 16) {
            colorArray[i] = 0.0
        }
    }
    
    // Compute the new state of the color vertices
    private func computeColorVertices() {
        let maxi = cursorDrawing ? cursorPos : stripSize
        var g: Float = startColor
        let gstep: Float = stripParams.colorCycleSpeed
        
        for i in 0..<maxi {
            for c in 0..<4 {
                // Some shade of green if cell is not empty
                colorArray[16*i + 4*c + 1] = (cellState[i] == 0) ? Float(0.0) : g
                // Cells which are very bright are slightly whitened
                colorArray[16*i + 4*c + 0] = ((g > 0.7) && (cellState[i] != 0)) ? (g - 0.6) : Float(0.0)
                colorArray[16*i + 4*c + 2] = ((g > 0.7) && (cellState[i] != 0)) ? (g - 0.6) : Float(0.0)
                // Transparent if cell is empty, otherwise opaque
                colorArray[16*i + 4*c + 3] = (cellState[i] == 0) ? Float(0.0) : Float(1.0)
            }
            g += gstep
            if (g > 1.0) {
                g = 0.2
            }
        }
        // Cycle the start color used above, to make the colors appear to fall
        startColor -= stripParams.colorFallSpeed
        if (startColor < 0.2) {
            startColor = 1.0
        }
        
        // If the cursor's drawing, work up from its position making sure the cells aren't too dark
        if (cursorDrawing) {
            let maxi = cursorPos - 1
            var cursorglow: Float = 0.8
            for i in stride(from: maxi, through: 0, by: -1) where cursorglow > 0.2 {
                // If there's some cursor-imparted glow left, use it
                if (colorArray[16*i + 4*0 + 1] < cursorglow) {
                    for c in 0..<4 {
                        // Some shade of green if cell is not empty
                        colorArray[16*i + 4*c + 1] = (cellState[i] == 0) ? Float(0.0) : cursorglow
                        // Cells which are very bright are slightly whitened
                        colorArray[16*i + 4*c + 0] = ((cursorglow > 0.7) && (cellState[i] != 0)) ? (cursorglow - 0.6) : Float(0.0)
                        colorArray[16*i + 4*c + 2] = ((cursorglow > 0.7) && (cellState[i] != 0)) ? (cursorglow - 0.6) : Float(0.0)
                        // Transparent if cell is empty, otherwise opaque
                        colorArray[16*i + 4*c + 3] = (cellState[i] == 0) ? Float(0.0) : Float(1.0)
                    }
                }
                cursorglow -= Float(gstep)
            }
        }
    }
    
    // It's a pity memset would require nasty assumptions about the internal format of floats...
    private func initializeTextureVertices(_ maxcell: Int) {
        for i in 0..<(maxcell * 8) {
            textureArray[i] = 0.0
        }
    }
    
    // Compute the texture coordinates for a single cell of the texture coord array
    private func computeTextureVertices(_ cellnum: Int) {
        // Get the glyph
        let g = cellContents[cellnum]
        // Work out the X and Y positions of the glyph in the texture
        // For an 8x8 grid, each glyph is 32x32 pixels in a 256x256 texture
        // X position: (glyph number % 8) * 32
        // Y position: (7 - (glyph number / 8)) * 32 (to account for row order)
        let ix = (g % 8) * 32
        let iy = (7 - (g / 8)) * 32
        // Convert to floats
        let tx = Float(ix) / 256.0
        let ty = Float(iy) / 256.0
        // Now work out the texture coordinates of the square containing the glyph
        // Texture coordinate for one glyph (32 pixel square out of 256x256 texture) = 32/256 = 0.125
        let glyphTexSize: Float = 0.125
        // Bottom left
        textureArray[8*cellnum + 0] = tx
        textureArray[8*cellnum + 1] = ty
        // Bottom right
        textureArray[8*cellnum + 2] = tx + glyphTexSize
        textureArray[8*cellnum + 3] = ty
        // Top right
        textureArray[8*cellnum + 4] = tx + glyphTexSize
        textureArray[8*cellnum + 5] = ty + glyphTexSize
        // Top left
        textureArray[8*cellnum + 6] = tx
        textureArray[8*cellnum + 7] = ty + glyphTexSize
    }
    
    // Compute quad, color and texture vertices for the cursor, bumped up by given offset
    private func computeCursor(_ cell: Int, offset: Float) {
        let size = stripParams.cellSize
        // Find the top quad
        let x = quadArray[0]
        let y = quadArray[1]
        let z = quadArray[2]
        let by = y - Float(quadSquishFactor) * size * (Float(cell) - offset)
        // Bottom left vertex
        quadArray[12*cell + 0] = x
        quadArray[12*cell + 1] = by
        quadArray[12*cell + 2] = z
        // Bottom right vertex
        quadArray[12*cell + 3] = x + size
        quadArray[12*cell + 4] = by
        quadArray[12*cell + 5] = z
        // Top right vertex
        quadArray[12*cell + 6] = x + size
        quadArray[12*cell + 7] = by + size
        quadArray[12*cell + 8] = z
        // Top left vertex
        quadArray[12*cell + 9] = x
        quadArray[12*cell + 10] = by + size
        quadArray[12*cell + 11] = z
        // Texture is just a call to self
        cellContents[cell] = cursorGlyph
        computeTextureVertices(cell)
        
        // Color is easy -- bright white at all four corners if drawing, else black
        let cc = cursorDrawing ? 1.0 : 0.0
        for c in 0..<4 {
            colorArray[16*cell + 4*c + 0] = Float(cc)
            colorArray[16*cell + 4*c + 1] = Float(cc)
            colorArray[16*cell + 4*c + 2] = Float(cc)
            colorArray[16*cell + 4*c + 3] = Float(1.0)
        }
    }
    
    // Number of floats written per vertex: x,y,z, r,g,b,a, u,v
    static let floatsPerVertex = 9

    // Upper bound of the quads writeQuads may emit: every cell plus three motion trails
    var maxQuadsPerDraw: Int {
        return stripSize + 3
    }

    // Write one cell of the arrays as four vertices (bottom left, bottom right, top right, top left)
    // yOffset moves the quad up, color replaces the per-vertex colors if given
    private func emitQuad(_ cell: Int, yOffset: Float, color: SIMD4<Float>?, to p: inout UnsafeMutablePointer<Float>) {
        for v in 0..<4 {
            let qi = 12*cell + 3*v
            p[0] = quadArray[qi]
            p[1] = quadArray[qi + 1] + yOffset
            p[2] = quadArray[qi + 2]
            if let c = color {
                p[3] = c.x
                p[4] = c.y
                p[5] = c.z
                p[6] = c.w
            } else {
                let ci = 16*cell + 4*v
                p[3] = colorArray[ci]
                p[4] = colorArray[ci + 1]
                p[5] = colorArray[ci + 2]
                p[6] = colorArray[ci + 3]
            }
            let ti = 8*cell + 2*v
            p[7] = textureArray[ti]
            p[8] = textureArray[ti + 1]
            p += MatrixStrip.floatsPerVertex
        }
    }

    // Write the vertices of everything this strip draws, in draw order, into the buffer.
    // Returns the number of quads written. This replaces drawSelf, which issued the GL calls.
    func writeQuads(into buffer: UnsafeMutablePointer<Float>) -> Int {
        var p = buffer
        var quads = 0

        // Work out the last cell we actually need to draw
        var lastcell = (cursorDrawing) ? cursorPos : (stripSize - 1)
        if (lastcell > lastVisibleCell) {
            lastcell = lastVisibleCell
        }

        // Now draw all cells from firstVisibleCell to lastcell
        let first = firstVisibleCell * 4
        let count = (1 + lastcell - firstVisibleCell) * 4
        if (count == 0) {
            return 0
        }
        if (first < 0) {
            logError("drawSelf", note: "Likely error: first < 0")
        }
        if ((count % 4) != 0 || (count / 4) > stripSize) {
            logError("drawSelf", note: "Likely error: count incorrect")
        }
        // A negative first or count draws nothing; never read past the end of the arrays
        if (first >= 0 && count > 0) {
            let lastIndex = min(firstVisibleCell + count / 4, stripSize)
            for cell in firstVisibleCell..<lastIndex {
                emitQuad(cell, yOffset: 0.0, color: nil, to: &p)
                quads += 1
            }
        }

        // Now we draw some motion trails behind the falling cursor.
        // You don't consciously notice it, but it makes a big difference.
        if (cursorDrawing && cursorPos >= 0 && cursorPos < stripSize) {
            let jitter = 0.75 * stripParams.cursorSpeed * stripParams.cellSize

            for i in 0..<3 {
                let tenths = Float(i) * 0.1
                // jitter translation moves up a bit more for every trail
                let offset = jitter * Float(i + 1)
                let trailColor = SIMD4<Float>(1.0 - tenths, 1.0 - tenths, 1.0 - tenths, 0.5 - tenths)
                emitQuad(cursorPos, yOffset: offset, color: trailColor, to: &p)
                quads += 1
            }
        }

        return quads
    }
    
    // Animate the strip, return true if the entire lifecycle of this strip is complete
    var animateSelfIsComplete: Bool {
        // First, are we about to splat into the screen?
        let nearfront = (Double(-myZ) - Double(stripParams.minDepth)) < 5.0
        if (nearfront) {
            // If so, we want a 1.0 probability of the cells being dead by the time they move the last 5.0
            let zapchance = 1.0 / (5.0 / Double(stripParams.driftSpeed))
            // Zap some random cells
            for c in stride(from: stripSize - 1, through: 0, by: -1) {
                if (Double.random(in: 0.0...1.0) < zapchance) {
                    cellState[c] = 0
                    cellContents[c] = 0
                    computeTextureVertices(c)
                }
            }
        }
        
        // Now for normal movement. Move the cursor down.
        cursorOffset -= stripParams.cursorSpeed
        if (cursorOffset < 0) {
            cursorOffset = 1.0
            // Cursor has fallen to the bottom of its cell.
            // Paint the cell with whatever is appropriate for the cursor mode
            if (cursorDrawing) {
                cellState[cursorPos] = cursorState
                cellContents[cursorPos] = cursorGlyph
                computeTextureVertices(cursorPos)
                // Move the cursor down a cell and pick a random glyph
                cursorPos += 1
                // Should we change the cursor's draw state?
                if (Int.random(in: 0..<100) < stripParams.cursorChangeProbability) {
                    // Pick a different state
                    randomizeCursorState(cursorState)
                }
            } else {
                // We're in erase-only mode
                cellState[cursorPos] = 0
                cellContents[cursorPos] = 0
                computeTextureVertices(cursorPos)
                cursorPos += 1
            }
        }
        
        // When we get to the bottom of the strip or the screen, see if we're in draw mode.
        // If so, go into erase mode. If we're already in erase mode, return true 'cause we're done.
        let minY = myZ * Float(tanFov)
        if ((cursorPos >= stripSize) || (quadArray[12*cursorPos + 10] < minY)) {
            if (cursorDrawing) {
                cursorPos = 0
                cursorDrawing = false
            } else {
                return true
            }
        }
        
        if (framecounter == stripParams.framesPerLivingCellChange) {
            framecounter = 0
            randomizeCursorGlyph()
            // Animate the cells based on their state
            // Work from the bottom up, as some cells take their value from the cells above
            for c in stride(from: stripSize - 1, through: 0, by: -1) {
                if ((cellState[c] > 1) || (nearfront && cellState[c] > 0)) {
                    // Animated cell, will change glyph
                    // If it's the top cell, give it a random value
                    if (c == 0) {
                        cellContents[c] = 1 + Int.random(in: 0..<(stripParams.numGlyphs - 1))
                    } else if (cellState[c-1] <= 1) {
                        // If the cell above isn't alive, give this one a random value
                        cellContents[c] = 1 + Int.random(in: 0..<(stripParams.numGlyphs - 1))
                    } else {
                        // Otherwise give this one the value of the cell above
                        cellContents[c] = cellContents[c-1]
                    }
                    // Decrement state to age the cell
                    cellState[c] -= 1
                    if (cellState[c] < 0) {
                        cellState[c] = 0
                    }
                    // A cell is never less alive than the one below it
                    if (c < stripSize - 1) {
                        if (cellState[c+1] > cellState[c]) {
                            cellState[c] = cellState[c+1]
                        }
                    }
                    // Recompute the cell's texture based on the new glyph contents
                    computeTextureVertices(c)
                }
            }
        } else {
            framecounter += 1
        }
        
        // Generate color vertices
        computeColorVertices()
        
        // Move the strip towards the viewer
        myZ += stripParams.driftSpeed
        if (Double(-myZ) < Double(stripParams.minDepth)) {
            return true
        }
        
        // If we fell off the sides of the screen, we're done
        let maxX = -myZ * Float(tanFov) * stripParams.aspectRatio
        let cursLX = quadArray[12*cursorPos + 9] // Top left x
        let cursRX = quadArray[12*cursorPos + 6] // Top right x
        if ((cursLX > maxX) || (cursRX < -maxX)) {
            return true
        }
        
        // Don't need this any more
        computeQuadVertices(stripSize, x: myX, y: myY, z: myZ)
        
        // Generate the cursor
        computeCursor(cursorPos, offset: cursorOffset)
        
        // I'm not dead yet!
        return false
    }
}