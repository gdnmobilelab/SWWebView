import Foundation
import JavaScriptCore

/// JSContext has no built-in support for setTimeout, setInterval, etc. So we need to manually
/// add that support into the context. All public methods are exactly as you'd expect. As documented:
/// https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/setTimeout
class TimeoutManager: NSObject {

    @objc fileprivate class TimeoutArguments: NSObject {
        let delay: Double
        let funcToRun: JSValue
        let args: [Any]
        let timeoutIndex: Int64
        let isInterval: Bool

        init(delay: Double, funcToRun: JSValue, args: [Any], timeoutIndex: Int64, isInterval: Bool) {
            self.delay = delay
            self.funcToRun = funcToRun
            self.args = args
            self.timeoutIndex = timeoutIndex
            self.isInterval = isInterval
        }
    }

    fileprivate var lastTimeoutIndex: Int64 = -1

    /// Couldn't find an easy way to cancel call after it's been set, so instead we store cancelled
    /// indexes in this set, and check when the timeout is run.
    fileprivate var cancelledTimeouts = Set<Int64>()
    var stopAllTimeouts = false

    /// Provided by the ServiceWorkerExecutionEnvironment, and ensures that all our timeouts run on
    /// the correct thread.
    weak var thread: Thread?

    init(for thread: Thread, in context: JSContext) {
        self.thread = thread
        super.init()

        // In order to add these to a JSContext, we have to cast our functions to Obj-C conventions, then to AnyObject.

        let clearTimeout = unsafeBitCast((self.clearTimeout as @convention(block) (Int64) -> Void), to: AnyObject.self)
        let setTimeout = unsafeBitCast((self.setTimeout as @convention(block) () -> Int64), to: AnyObject.self)
        let setInterval = unsafeBitCast((self.setInterval as @convention(block) () -> Int64), to: AnyObject.self)

        // Then actually attach them to the specific variable names. clearTimeout and clearInterval do the exact
        // same thing so we just reuse the same function.

        GlobalVariableProvider.add(variable: clearTimeout, to: context, withName: "clearInterval")
        GlobalVariableProvider.add(variable: clearTimeout, to: context, withName: "clearTimeout")
        GlobalVariableProvider.add(variable: setTimeout, to: context, withName: "setTimeout")
        GlobalVariableProvider.add(variable: setInterval, to: context, withName: "setInterval")
    }

    fileprivate func setTimeout() -> Int64 {
        guard let params = self.getArgumentsForSetCall(isInterval: false) else {
            return -1
        }

        self.perform(#selector(self.runTimeout(_:)), with: params, afterDelay: params.delay)

        return params.timeoutIndex
    }

    fileprivate func setInterval() -> Int64 {
        guard let params = self.getArgumentsForSetCall(isInterval: true) else {
            return -1
        }

        self.perform(#selector(self.runTimeout(_:)), with: params, afterDelay: params.delay)

        return params.timeoutIndex
    }

    fileprivate func clearTimeout(_ index: Int64) {
        self.cancelledTimeouts.insert(index)
    }

    @objc fileprivate func runTimeout(_ timeout: TimeoutArguments) {

        if self.cancelledTimeouts.contains(timeout.timeoutIndex) == true {

            // There isn't any way to proactively cancel this before it runs, but when it does
            // we check to see if the index is in our collection of cancelled timeouts. If it is,
            // we return immediately.

            self.cancelledTimeouts.remove(timeout.timeoutIndex)

            return

        } else if self.stopAllTimeouts {

            // If we've stopped all execution (i.e. the worker is shutting down) then we shouldn't
            // fire either.

            return
        }

        // If we've got this far, it's still a valid timeout call. So call it.

        timeout.funcToRun.call(withArguments: timeout.args)

        if timeout.isInterval {

            // If this was a setInterval call as opposed to a setTimeout call, we need to keep firing
            // the function repeatedly until clearInterval is called.

            self.perform(#selector(TimeoutManager.runTimeout(_:)), with: timeout, afterDelay: timeout.delay)
        }
    }

    /// setTimeout() and setInteral() have a dynamic argument length - after
    /// the function and delay, the rest are arguments to be sent to the function
    /// when it runs. So we need to run a specific handler for this.
    fileprivate func getArgumentsForSetCall(isInterval: Bool) -> TimeoutArguments? {

        ServiceWorkerExecutionEnvironment.ensureContextIsOnCorrectThread()

        do {
            guard var args = JSContext.currentArguments() else {

                // This shouldn't ever really happen as this function is always
                // run in a JSContext, but you never know...
                throw ErrorMessage("Could not get current argument list")
            }

            if args.count == 0 {
                throw ErrorMessage("Insufficient arguments provided. Must provide function")
            }

            guard let funcToRun = args.removeFirst() as? JSValue else {
                throw ErrorMessage("Could not extract function")
            }

            var timeout: Double = 0

            if args.count > 0 {

                // The delay argument is optional, but if it's provided we need to
                // parse it into a Double (so that division by 1000 isn't rounded to
                // a whole number)

                guard let specifiedTimeout = args.removeFirst() as? JSValue else {
                    throw ErrorMessage("Could not extract timeout value provided")
                }

                // Browsers let you use strings, so...
                guard let timeoutFromString = Double(specifiedTimeout.toString()) else {
                    throw ErrorMessage("Could not interpret the timeout provided as a number")
                }

                timeout = timeoutFromString
            }

            // Not sure what logic browser environments use, but all we require is that every timeout
            // call has its own unique ID. So we're just using an incremental number here.
            self.lastTimeoutIndex += 1

            // Divided by 1000 because the native timeout is in seconds, wheras the JS timeout is in ms

            return TimeoutArguments(delay: timeout / 1000, funcToRun: funcToRun, args: args, timeoutIndex: self.lastTimeoutIndex, isInterval: isInterval)

        } catch {

            if let ctx = JSContext.current() {
                let err = JSValue(newErrorFromMessage: "\(error)", in: ctx)
                ctx.exception = err
            } else {
                Log.error?("\(error)")
            }
            return nil
        }
    }
}
