// This isn't actually included in the final JS bundle - instead the code is used in
// the ServiceWorker bundle to mirror console messages in the native log. But we
// include it here so we can run some tests on it.

export default function(funcToCall) {
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
}
