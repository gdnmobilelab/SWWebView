import Foundation
import JavaScriptCore

/// JSContext has no built-in support for setTimeout, setInterval, etc. So we need to manually
/// add that support into the context. All public methods are exactly as you'd expect. As documented:
/// https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/setTimeout
class TimeoutManager {

    fileprivate struct Arguments {
        let delay: Double
        let funcToRun: JSValue
        let args: [Any]
    }

    fileprivate struct Interval {
        var timeout: Double
        var function: JSValue
        var timeoutIndex: Int
        var args: [Any]
    }

    var lastTimeoutIndex: Int = -1

    /// Couldn't find an easy way to cancel a dispatch_after, so instead, when the dispatch completes
    /// we check this array to see if the timeout has been cancelled. If it has, we don't run the
    /// corresponding JS function.
    var cancelledTimeouts = Set<Int>()
    var stopAllTimeouts = false

    weak var thread: Thread?

    init(for thread: Thread, in context: JSContext) {
        self.thread = thread

        let clearInterval = unsafeBitCast((self.clearIntervalFunction as @convention(block) (Int) -> Void), to: AnyObject.self)
        let clearTimeout = unsafeBitCast((self.clearTimeoutFunction as @convention(block) (Int) -> Void), to: AnyObject.self)
        let setTimeout = unsafeBitCast((self.setTimeoutFunction as @convention(block) () -> Int), to: AnyObject.self)
        let setInterval = unsafeBitCast((self.setIntervalFunction as @convention(block) () -> Int), to: AnyObject.self)

        GlobalVariableProvider.add(variable: clearInterval, to: context, withName: "clearInterval")
        GlobalVariableProvider.add(variable: clearTimeout, to: context, withName: "clearTimeout")
        GlobalVariableProvider.add(variable: setTimeout, to: context, withName: "setTimeout")
        GlobalVariableProvider.add(variable: setInterval, to: context, withName: "setInterval")
    }

    fileprivate func setIntervalFunction() -> Int {

        guard let params = self.getArgumentsForSetCall() else {
            return -1
        }

        self.lastTimeoutIndex += 1

        let interval = Interval(timeout: params.delay, function: params.funcToRun, timeoutIndex: lastTimeoutIndex, args: params.args)

        fireInterval(interval)

        return self.lastTimeoutIndex
    }

    fileprivate func fireInterval(_ interval: Interval) {

        DispatchQueue.global().asyncAfter(deadline: .now() + (interval.timeout / 1000), execute: {

            if self.cancelledTimeouts.contains(interval.timeoutIndex) == true {
                self.cancelledTimeouts.remove(interval.timeoutIndex)
                return
            } else if self.stopAllTimeouts {
                return
            } else {

                // ensure that we perform this function on our worker thread

                guard let thread = self.thread else {
                    Log.error?("Tried to execute setInterval function but environment no longer exists")
                    return
                }

                interval.function.perform(#selector(JSValue.call), on: thread, with: interval.args, waitUntilDone: false)

                self.fireInterval(interval)
            }
        })
    }

    fileprivate func clearIntervalFunction(_ index: Int) {
        self.clearTimeoutFunction(index)
    }

    /// setTimeout() and setInteral() have a dynamic argument length - after
    /// the function and delay, the rest are arguments to be sent to the function
    /// when it runs. So we need to run a specific handler for this.
    fileprivate func getArgumentsForSetCall() -> Arguments? {

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

            return Arguments(delay: timeout, funcToRun: funcToRun, args: args)

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

    fileprivate func setTimeoutFunction() -> Int {

        guard let params = self.getArgumentsForSetCall() else {
            return -1
        }

        self.lastTimeoutIndex += 1

        let thisTimeoutIndex = lastTimeoutIndex

        DispatchQueue.global().asyncAfter(deadline: .now() + (params.delay / 1000), execute: {
            if self.cancelledTimeouts.contains(thisTimeoutIndex) == true {
                self.cancelledTimeouts.remove(thisTimeoutIndex)
                return
            } else if self.stopAllTimeouts {
                return
            } else {

                guard let thread = self.thread else {
                    Log.error?("Tried to execute setInterval function but environment no longer exists")
                    return
                }

                params.funcToRun.perform(#selector(JSValue.call), on: thread, with: params.args, waitUntilDone: false)
            }
        })

        return thisTimeoutIndex
    }

    fileprivate func clearTimeoutFunction(_ index: Int) {
        self.cancelledTimeouts.insert(index)
    }
}
