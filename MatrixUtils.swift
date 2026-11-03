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

// This file contains the error logging helper used throughout the screensaver.

func logError(_ function: String, note: String) {
    // The main change between this function and the Apple version is that
    // this one counts the number of errors, and silently ignores errors
    // after the first three.
    // This is because some users discovered that RedPill would report errors
    // *even when everything worked fine*, and their system log would
    // get filled up with 30 lines of error text every second until it ate
    // all available disk space. Ouch!

    // Static variable to count errors, keeping track across calls
    struct ErrorCounter {
        nonisolated(unsafe) static var count = 0
    }

    if ErrorCounter.count < 4 {
        ErrorCounter.count += 1
        NSLog("RedPill Error in %@: %@", function, note)
    } else if ErrorCounter.count == 4 {
        ErrorCounter.count += 1
        NSLog("RedPill Error in %@: %@ (suppressing further errors)", function, note)
    }
}
