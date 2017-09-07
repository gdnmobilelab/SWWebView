//
//  Bootstrap.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 15/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker
import PromiseKit

public class TestBootstrap: NSObject {
    override init() {
        super.init()
        //        Log.enable()

        let p = Promise(value: ())
        
        Log.debug = { NSLog($0) }
        Log.info = { NSLog($0) }
        Log.warn = { NSLog($0) }
        Log.error = { NSLog($0) }
    }
}
