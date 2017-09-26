import Foundation
import ServiceWorker
import PromiseKit

public class TestBootstrap: NSObject {
    override init() {
        super.init()
        //        Log.enable()

        Log.debug = { NSLog($0) }
        Log.info = { NSLog($0) }
        Log.warn = { NSLog($0) }
        Log.error = { NSLog($0) }
    }
}
