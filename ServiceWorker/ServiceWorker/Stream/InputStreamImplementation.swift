import Foundation

public class InputStreamImplementation: InputStream {

    // Get an error about abstract classes if we do not implement this. No idea why.
    public override var delegate: StreamDelegate? {
        get {
            return self._delegate
        }
        set(val) {
            self._delegate = val
        }
    }

    fileprivate var _streamStatus: Stream.Status = .notOpen

    public internal(set) override var streamStatus: Stream.Status {
        get {
            return self._streamStatus
        }
        set(val) {
            self._streamStatus = val
        }
    }

    fileprivate var _streamError: Error?

    public internal(set) override var streamError: Error? {
        get {
            return self._streamError
        }
        set(val) {
            self._streamError = val
        }
    }

    var runLoops: [RunLoop: Set<RunLoopMode>] = [:]

    var pendingEvents: [Stream.Event] = []

    fileprivate weak var _delegate: StreamDelegate?

    internal func throwError(_ error: Error) {
        self._streamStatus = .error
        self._streamError = error
        self.emitEvent(event: .errorOccurred)
    }

    internal func emitEvent(event: Stream.Event) {
        if self.runLoops.count > 0 {

            // If we're already scheduled in a run loop, send immediately

            self.runLoops.forEach({ loopPair in
                loopPair.key.perform(inModes: Array(loopPair.value), block: {
                    self.delegate?.stream?(self, handle: event)
                })
            })

        } else {

            // Otherwise store these events to be sent when we are scheduled

            self.pendingEvents.append(event)
        }
    }

    public override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoopMode) {

        var modeArray = self.runLoops[aRunLoop] ?? Set<RunLoopMode>()
        modeArray.insert(mode)
        self.runLoops[aRunLoop] = modeArray

        // send any pending events that were fired when there was no runloop
        self.pendingEvents.forEach { self.emitEvent(event: $0) }
        self.pendingEvents.removeAll()
    }

    public override func remove(from aRunLoop: RunLoop, forMode mode: RunLoopMode) {

        guard var existing = self.runLoops[aRunLoop] else {
            return
        }
        existing.remove(mode)

        if existing.count == 0 {
            self.runLoops.removeValue(forKey: aRunLoop)
        } else {
            self.runLoops[aRunLoop] = existing
        }
    }
}
