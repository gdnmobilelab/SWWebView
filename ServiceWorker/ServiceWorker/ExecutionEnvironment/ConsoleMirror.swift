import Foundation
import JavaScriptCore

@objc private protocol ConsoleMirrorExports: JSExport {
    func mirror(_ level: String, _ msg: JSValue)
}

/// JavascriptCore has a fully functional console, just like the browser. But ideally we will also
/// mirror JSC console statements in our logs, too. There are no console events as such, so we have
/// to override the functions on the console object itself.
@objc class ConsoleMirror: NSObject, ConsoleMirrorExports {

    var originalConsole: JSValue?

    init(in context: JSContext) throws {
        self.originalConsole = context.globalObject.objectForKeyedSubscript("console")
        super.init()

        guard let proxyFunc = context.evaluateScript("""
             (function(funcToCall) {
                let levels = ["debug", "info", "warn", "error", "log"];
                let originalConsole = console;

                let levelProxy = {
                    apply: function(target, thisArg, argumentsList) {
                        // send to original console logging function
                        target.apply(thisArg, argumentsList);

                        let level = levels.find(l => originalConsole[l] == target);

                        funcToCall(level, argumentsList);
                    }
                };

                let interceptors = levels.map(
                    l => new Proxy(originalConsole[l], levelProxy)
                );

                return new Proxy(originalConsole, {
                    get: function(target, name) {
                        let idx = levels.indexOf(name);
                        if (idx === -1) {
                            // not intercepted
                            return target[name];
                        }
                        return interceptors[idx];
                    }
                });
            })

        """) else {
            throw ErrorMessage("Cannot create console proxy")
        }

        let mirrorConvention: @convention(block) (String, JSValue) -> Void = self.mirror

        guard let consoleProxy = proxyFunc.call(withArguments: [unsafeBitCast(mirrorConvention, to: AnyObject.self)]) else {
            throw ErrorMessage("Could not create instance of console proxy")
        }

        GlobalVariableProvider.add(variable: consoleProxy, to: context, withName: "console")
    }

    func cleanup() {
        guard let console = self.originalConsole else {
            Log.error?("Cleanup with no original console. This should not happen.")
            return
        }

        console.context.globalObject.setValue(console, forProperty: "console")
        self.originalConsole = nil
    }

    fileprivate func mirror(_ level: String, _ msg: JSValue) {

        let values = msg.toArray()
            .map { val in

                if let str = val as? String {
                    return str
                }

                return String(describing: val)
            }
            .joined(separator: ",")

        switch level {
        case "info":
            Log.info?(values)
        case "log":
            Log.info?(values)
        case "debug":
            Log.debug?(values)
        case "warn":
            Log.warn?(values)
        case "error":
            Log.error?(values)
        default:
            Log.error?("Tried to log to JSC console at an unknown level.")
        }
    }
}
