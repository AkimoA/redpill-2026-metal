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
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
// or visit <URL:http://www.fsf.org/>

import ScreenSaver
import Metal
import QuartzCore
import os
import Foundation

// This is the main control object for the screensaver.
// It inherits from and implements the ScreenSaverView API.

@objc(MatrixView)
public class MatrixView: ScreenSaverView {
    
    // The view with the CAMetalLayer where we draw the graphics
    private var metalView: MatrixMetalView?
    
    // The Metal renderer (device state, pipeline, buffers, projection)
    private var renderer: MatrixRenderer?
    
    // Flag indicating whether this screensaver process is drawing on the main screen,
    // or on a second monitor
    private var isMainScreen: Bool = false
    // Similar flag for preference checkbox
    private var mainScreenOnly: Bool = false
    // and for whether we're running in the preview box
    private var _isPreview: Bool = false
    
    public override var isPreview: Bool {
        return _isPreview
    }
    
    // The screen aspect ratio, stored and used to compute the ranges of X and Y allowed at given depth
    private var aspectRatio: Float = 0.0
    
    private var x: Float = 0.0
    private var y: Float = 0.0
    
    // The texture containing the glyphs
    private var matrixGlyphs: MatrixTexture?
    
    // Array of strips of Matrix
    private var matrixStrips: [MatrixStrip] = []
    
    // Parameters for the animation
    private var saverParams = MatrixStripParams(
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
    
    // Preferences window
    private var prefsWindow: MatrixPrefsWindow?
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        
        _isPreview = isPreview
        
        // Register for stop notification
        NSLog("[MATRIX] Setting up willStop notification observer")
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(screenSaverWillStop),
            name: NSNotification.Name("com.apple.screensaver.willstop"),
            object: nil
        )
        NSLog("[MATRIX] willStop notification observer registered")
        
        // Work out what our defaults are called
        let bundle = Bundle(for: type(of: self))
        guard let identifier = bundle.bundleIdentifier else {
            logError("initWithFrame", note: "Trying to initialize preferences but identifier is nil!")
            return nil
        }
        
        if let defaults = ScreenSaverDefaults(forModuleWithName: identifier) {
            // Create and register an array of "default defaults"
            // Note that since the screensaver parameters are mostly between 0 and something < 1 internal,
            // and UI sliders only have a resolution of 0.1, we multiply 'em all by 100, so 0.15 becomes 15.
            let defdefs: [String: Any] = [
                stripsKey: Float(stripsDefault) ?? 50.0,
                velocityKey: Float(velocityDefault) ?? 40.0,
                depthKey: Float(depthDefault) ?? 200.0,
                cyclingKey: Float(cyclingDefault) ?? 5.0,
                fallingKey: Float(fallingDefault) ?? 2.0,
                cursorKey: Float(cursorDefault) ?? 10.0,
                fogKey: Float(fogDefault) ?? 15.0,
                topstartKey: topstartDefaultBoolean,
                mainonlyKey: mainonlyDefaultBoolean,
                spoonKey: spoonDefaultBoolean
            ]
            
            defaults.register(defaults: defdefs)
        }
        
        // Now load either those defaults, or the user's prior choice of preferences
        loadDefaults(nil)
        
        // Work out if we're running on the main display
        // This lets us offer a "run on main screen only" option for when the GPU doesn't like running two monitors
        isMainScreen = ((frame.origin.x == 0 && frame.origin.y == 0) || _isPreview)
        
        // If we're running in preview mode, we need to set up a notification so the preferences dialog
        // can tell us when we need to reload our parameters to show the changes.
        // Note that the notification center should always be set up, otherwise it's possible to cause
        // race conditions that result in a crash by clicking buttons quickly and repeatedly.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loadDefaults(_:)),
            name: Notification.Name(prefsNotification),
            object: nil
        )
        
        // Find a Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            logError("initWithFrame", note: "Failed to find a Metal device. Your graphics card can't cope with this screensaver, sorry.")
            return nil
        }
        
        // Create the renderer (loads shaders, builds the pipeline)
        guard let newRenderer = MatrixRenderer(device: device, bundle: bundle) else {
            logError("initWithFrame", note: "Failed to initialize Metal. Not my fault.")
            return nil
        }
        renderer = newRenderer
        
        // Create the Metal view
        let newMetalView = MatrixMetalView(frame: NSRect(origin: .zero, size: frame.size), device: device)
        metalView = newMetalView
        
        // Make the Metal view a subview of us
        addSubview(newMetalView)
        
        // Set the animation speed
        animationTimeInterval = 1.0/30.0
        
        // Initialize the parameters which aren't editable in the dialog box.
        // The idea is to parameterize everything in advance, so that you can
        // change what's editable in the dialog without too much pain.
        saverParams.cellSize = 2.0
        saverParams.maxCellLife = 120
        saverParams.numGlyphs = numGlyphs
        saverParams.cursorChangeProbability = 20
        saverParams.cursorLiveProbability = 30
        saverParams.cursorStaticProbability = 30
        saverParams.cursorEmptyProbability = 10
        saverParams.framesPerLivingCellChange = 3
        saverParams.minDepth = Float(clipNear)
        saverParams.spawnChance = 0.2
        
        // Set the initial aspect ratio if we're not using a frame
        aspectRatio = Float(frame.size.width / frame.size.height)
        saverParams.aspectRatio = aspectRatio
        newRenderer.setAspectRatio(aspectRatio)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Handle a change of preferences/configuration
    @objc func loadDefaults(_ notification: Notification?) {
        // Work out what our defaults are called
        guard let identifier = Bundle(for: type(of: self)).bundleIdentifier else {
            logError("initWithFrame", note: "Trying to load preferences but identifier is nil.")
            return
        }
        
        // Load defaults
        if let defaults = ScreenSaverDefaults(forModuleWithName: identifier) {
            // Scale the values appropriately and set the saver parameters
            saverParams.maxStrips = Int(defaults.float(forKey: stripsKey))
            saverParams.driftSpeed = defaults.float(forKey: velocityKey) / 100.0
            saverParams.maxDepth = defaults.float(forKey: depthKey)
            saverParams.colorCycleSpeed = defaults.float(forKey: cyclingKey) / 100.0
            saverParams.colorFallSpeed = defaults.float(forKey: fallingKey) / 100.0
            saverParams.cursorSpeed = defaults.float(forKey: cursorKey) / 100.0
            saverParams.fogDensity = defaults.float(forKey: fogKey) / 100.0
            saverParams.minStartY = defaults.bool(forKey: topstartKey) ? 1.0 : 0.0
            mainScreenOnly = defaults.bool(forKey: mainonlyKey)
        }
    }
    
    public override func startAnimation() {
        // Anything to do?
        if (mainScreenOnly && !isMainScreen) {
            return
        }
        
        guard let metalView = metalView, let renderer = renderer else {
            logError("startAnimation", note: "OS called startAnimation before Metal initialized. This should not happen.")
            return
        }
        
        // stopAnimation removes the view, so put it back if need be
        if metalView.superview == nil {
            addSubview(metalView)
        }
        
        // Clear the screen to black, so that the screensaver fades to black
        renderer.render(layer: metalView.metalLayer, strips: [], glyphs: nil, fogEnabled: false)
        
        // Allocate the texture storage object if necessary
        if matrixGlyphs == nil {
            matrixGlyphs = MatrixTexture(withDevice: renderer.device)
        }
        
        // Load the texture bitmap
        if !(matrixGlyphs?.fileLoaded ?? false) {
            // Load the PNG of glyphs
            let success = matrixGlyphs?.loadFromFile("Glyphs.png") ?? false
            if !success {
                logError("startAnimation", note: "Failed to load Glyphs.png texture")
            }
        }
        
        // Set up some parameters
        x = 0.0
        y = 0.0
        
        super.startAnimation()
    }
    
    public override func stopAnimation() {
        super.stopAnimation()
        
        // Aggressive cleanup - stop everything
        renderer?.waitUntilIdle()
        metalView?.removeFromSuperview()
        
        // Release textures
        matrixGlyphs = nil
    }
    
  @objc func screenSaverWillStop() {
          NSLog("screenSaverWillStop called - applying version-specific workaround")
          
          if #available(macOS 14.0, *) {
              // macOS 14.0+ (includes macOS 26/Tahoe): Use delayed exit to fix termination issues tx to the Aerials Project 
              NSLog("macOS 14.0+ detected, using 2-second delayed exit")
              DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                  NSLog("Exiting application now")
                  exit(0)
              }
          } else {
              // For older macOS versions, ensure proper cleanup and exit
              NSLog("macOS older than 14.0, calling stopAnimation and exit")
              stopAnimation()  // Ensure cleanup happens
              exit(0)  // Force exit to ensure screensaver terminates properly
          }
      }
    
    public override func animateOneFrame() {
      guard metalView != nil else {
            logError("animateOneFrame", note: "OS called animateOneFrame before Metal view initialized. This should not happen.")
            return
        }
        
        // Anything to do?
        if (mainScreenOnly && !isMainScreen) {
            return
        }
        
      guard matrixGlyphs != nil else {
            // Unfortunately the OS calling "draw frame" before "initialize screensaver" happens quite a lot,
            // and shouldn't be reported as an error
            return
        }
        
        // Allocate the array of matrix strips if necessary
        if matrixStrips.isEmpty {
            matrixStrips = []
        }
        
        // If the number of Matrix strips is less than the max, create another every now and again
        let maxi = matrixStrips.count
        if ((maxi < saverParams.maxStrips) && (Double.random(in: 0.0...1.0) < Double(saverParams.spawnChance))) {
            // Copy the current parameters
            var tweaked = saverParams
            // If the velocity is 0, we make the depth random
            let d: Float
            if (saverParams.driftSpeed == 0.0) {
                d = -Float(clipNear) - Float.random(in: 0.0...1.0) * Float(clipFar - clipNear)
            } else {
                // Depth is whatever the current parameters are, only negative (away from the viewer)
                d = -saverParams.maxDepth
            }
            
            // Work out range of X and Y at that depth
            let ys = -d * Float(tanFov)
            let xs = ys * aspectRatio
            
            // Position the strip
            x = xs * Float.random(in: -1.0...1.0)
            y = Float(saverParams.cellSize) + ys * (saverParams.minStartY == 0.0 ? Float.random(in: 0.0...1.0) : saverParams.minStartY)
            
            // Work out how many cells it needs to cover the screen vertically
            let cells = Int(((y + ys) / Float(saverParams.cellSize) / Float(quadSquishFactor)) + 2)
            
            // Tweak the cursor speed a bit, randomly
            tweaked.cursorSpeed = saverParams.cursorSpeed + 0.2 * Float.random(in: 0.0...1.0)
            // I guess we could tweak the other parameters to vary things a bit, but it looks good enough anyway
            
            // Now create a strip
            guard let newstrip = MatrixStrip(withCells: cells, x: x, y: y, z: d, params: tweaked) else {
                return
            }
            
            // Add it to the array
            if (saverParams.driftSpeed == 0.0) {
                // In "zero velocity mode", we need to find the first strip that's in front of this one
                var insertIndex = maxi
                for i in 0..<maxi {
                    let strip = matrixStrips[i]
                    if strip.z > d {
                        insertIndex = i
                        break
                    }
                }
                matrixStrips.insert(newstrip, at: insertIndex)
            } else {
                // In regular mode, strips are always added at the back
                if (maxi == 0) {
                    // Adding first strip to array, so add it to the end
                    matrixStrips.append(newstrip)
                } else {
                    // Add it to the start of the array
                    matrixStrips.insert(newstrip, at: 0)
                }
            }
        }
        
        // Animate all the strips
        var i = 0
        while i < matrixStrips.count {
            let strip = matrixStrips[i]
            if strip.animateSelfIsComplete {
                // Strip has finished doing anything interesting, so delete it from the array
                matrixStrips.remove(at: i)
                // The array is now one smaller, and we need to loop over the same index again
                i -= 1
                // Plus we can now spawn new strips faster
                if (saverParams.spawnChance < 1.0) {
                    saverParams.spawnChance += 0.05
                }
            }
            i += 1
        }
        
        // Draw the new state of all the strips
        drawMetal()
    }
    
    // Override setFrameSize to resize the Metal universe too.
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if let metalView = metalView {
            metalView.setFrameSize(newSize)
            resizeMetal(Int(newSize.width), Int(newSize.height))
        }
    }
    
    // Set up projection appropriately for the given screen rectangle
    private func resizeMetal(_ width: Int, _ height: Int) {
        guard let renderer = renderer else {
            logError("resizeMetal", note: "Screensaver called resizeMetal before Metal initialized. This should not happen.")
            return
        }
        
        guard width > 0 && height > 0 else {
            return
        }
        
        // 45 degrees FOV = 50mm lens on a 35mm camera, should look natural
        // Store the aspect ratio for later use
        aspectRatio = Float(width) / Float(height)
        saverParams.aspectRatio = aspectRatio
        
        renderer.setAspectRatio(aspectRatio)
    }
    
    private func drawMetal() {
        guard let metalView = metalView, let renderer = renderer, let matrixGlyphs = matrixGlyphs else {
            logError("drawMetal", note: "Screensaver called drawMetal called before Metal initialized. This should not happen.")
            return
        }
        
        // Fog is disabled if the fog value is zero
        let fogEnabled = (saverParams.fogDensity != 0.0)
        
        let glyphs = matrixGlyphs.mtltexture
        if glyphs == nil {
            logError("drawMetal", note: "Someone stole our texture, call the Metal texture police.")
        }
        
        // Clear the screen and draw all the strips by asking them to write their vertices
        renderer.render(layer: metalView.metalLayer, strips: matrixStrips, glyphs: glyphs, fogEnabled: fogEnabled)
    }
    
    // Configuration sheet handling
    override public var hasConfigureSheet: Bool {
        return true
    }
    
    override public var configureSheet: NSWindow? {
        // Always create a fresh instance of preferences window to avoid sheet reuse issues
        prefsWindow = MatrixPrefsWindow()
        // Force the window to load if it hasn't been loaded yet
        _ = prefsWindow?.window
        return prefsWindow?.window
    }
    
    // Clean up after ourselves
    deinit {
        DistributedNotificationCenter.default.removeObserver(self)
    }
}
