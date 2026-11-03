//
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
import ScreenSaver

// Strings to use when saving the preferences
let stripsKey = "strips"
let velocityKey = "velocity"
let depthKey = "depth"
let cyclingKey = "cycling"
let fallingKey = "falling"
let cursorKey = "cursor"
let fogKey = "fog"
let topstartKey = "topstart"
let mainonlyKey = "mainonly"
let spoonKey = "spoon"

// Default values for same
let stripsDefault = "50"
let velocityDefault = "40"
let depthDefault = "200"
let cyclingDefault = "5"
let fallingDefault = "2"
let cursorDefault = "10"
let fogDefault = "15"
let topstartDefault = "YES"
let topstartDefaultBoolean = true
let mainonlyDefault = "NO"
let mainonlyDefaultBoolean = false
let spoonDefault = "NO"
let spoonDefaultBoolean = false

// Notification to send the main object
let prefsNotification = "PreferencesChanged"

@objc(MatrixPrefsWindow)
public class MatrixPrefsWindow: NSWindowController {
    
    // IBOutlets for our controls from the nib file (matching original Objective-C names)
    @IBOutlet private var strips: NSSlider!
    @IBOutlet private var velocity: NSSlider!
    @IBOutlet private var depth: NSSlider!
    @IBOutlet private var cycling: NSSlider!
    @IBOutlet private var falling: NSSlider!
    @IBOutlet private var cursor: NSSlider!
    @IBOutlet private var fog: NSSlider!
    @IBOutlet private var topstart: NSButton!
    @IBOutlet private var mainonly: NSButton!
    @IBOutlet private var spoon: NSButton!
    @IBOutlet private var version: NSTextField?
    
    // Return the name of the nib file to load
    public override var windowNibName: String? {
        return "Matrix"
    }
    
    // Override to load defaults and version when window is loaded
    public override func windowDidLoad() {
        super.windowDidLoad()
        
        // Display version if version label exists
        displayVersion()
        
        // Load the default values into the controls
        loadDefaults(nil)
    }
    
    // Method to display the version
    private func displayVersion() {
        if let versionField = version {
            if let version = Bundle(for: type(of: self)).object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                versionField.stringValue = "Version \(version)"
            } else {
                versionField.stringValue = "Version Unknown"
            }
        }
    }
    

    
    @objc func loadDefaults(_ notification: Notification?) {
        // Work out what our defaults are called
        guard let identifier = Bundle(for: type(of: self)).bundleIdentifier else {
            logError("window", note: "Trying to load preferences but identifier is nil.")
            return
        }
        
        // Load defaults
        if let defaults = ScreenSaverDefaults(forModuleWithName: identifier) {
            // Scale the values appropriately and set the saver parameters
            strips?.floatValue = defaults.float(forKey: stripsKey)
            velocity?.floatValue = defaults.float(forKey: velocityKey)
            depth?.floatValue = defaults.float(forKey: depthKey)
            cycling?.floatValue = defaults.float(forKey: cyclingKey)
            falling?.floatValue = defaults.float(forKey: fallingKey)
            cursor?.floatValue = defaults.float(forKey: cursorKey)
            fog?.floatValue = defaults.float(forKey: fogKey)
            topstart?.state = defaults.bool(forKey: topstartKey) ? .on : .off
            mainonly?.state = defaults.bool(forKey: mainonlyKey) ? .on : .off
            spoon?.state = defaults.bool(forKey: spoonKey) ? .on : .off
        }
    }
    
    // Reset the values of the sliders to their defaults
    @IBAction func reset(_ sender: Any) {
        strips?.floatValue = Float(stripsDefault) ?? 50.0
        velocity?.floatValue = Float(velocityDefault) ?? 40.0
        depth?.floatValue = Float(depthDefault) ?? 200.0
        cycling?.floatValue = Float(cyclingDefault) ?? 5.0
        falling?.floatValue = Float(fallingDefault) ?? 2.0
        cursor?.floatValue = Float(cursorDefault) ?? 10.0
        fog?.floatValue = Float(fogDefault) ?? 15.0
        topstart?.state = topstartDefaultBoolean ? .on : .off
        mainonly?.state = mainonlyDefaultBoolean ? .on : .off
        spoon?.state = spoonDefaultBoolean ? .on : .off
    }
    
    // The About button takes them to a web site
    @IBAction func about(_ sender: Any) {
        if let url = URL(string: "https://github.com/AkimoA/RedPill-2025") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @IBAction func cancel(_ sender: Any) {
        window?.sheetParent?.endSheet(window!)
    }
    
    @IBAction func spoonclick(_ sender: Any) {
        // Handle spoon button click - may be connected from nib
        spoon?.isTransparent = false
    }
    

    
    @IBAction func ok(_ sender: Any) {
        guard let identifier = Bundle(for: type(of: self)).bundleIdentifier else {
            logError("ok", note: "Trying to save preferences but identifier is nil.")
            window?.sheetParent?.endSheet(window!)
            return
        }
        
        if let defaults = ScreenSaverDefaults(forModuleWithName: identifier) {
            // Set values based on new positions and states of UI elements
            defaults.set(strips?.floatValue ?? Float(stripsDefault) ?? 50.0, forKey: stripsKey)
            defaults.set(velocity?.floatValue ?? Float(velocityDefault) ?? 40.0, forKey: velocityKey)
            defaults.set(depth?.floatValue ?? Float(depthDefault) ?? 200.0, forKey: depthKey)
            defaults.set(cycling?.floatValue ?? Float(cyclingDefault) ?? 5.0, forKey: cyclingKey)
            defaults.set(falling?.floatValue ?? Float(fallingDefault) ?? 2.0, forKey: fallingKey)
            defaults.set(cursor?.floatValue ?? Float(cursorDefault) ?? 10.0, forKey: cursorKey)
            defaults.set(fog?.floatValue ?? Float(fogDefault) ?? 15.0, forKey: fogKey)
            defaults.set(topstart?.state == .on, forKey: topstartKey)
            defaults.set(mainonly?.state == .on, forKey: mainonlyKey)
            defaults.set(spoon?.state == .on, forKey: spoonKey)
            
            // Update to disk
            defaults.synchronize()
        }
        
        // Plug web site if user selects spoon mode
        if spoon?.state == .on {
            let alert = NSAlert()
            alert.messageText = "Realize"
            alert.informativeText = "There is no spoon."
            alert.runModal()
            about(sender)
        }
        
        // Tell the main screensaver loop to reload the preferences from us
        NotificationCenter.default.post(name: Notification.Name(prefsNotification), object: nil)
        
        window?.sheetParent?.endSheet(window!)
    }
}
