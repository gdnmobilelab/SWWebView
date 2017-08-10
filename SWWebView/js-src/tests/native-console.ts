export const log = function() {
    (window as any).webkit.messageHandlers.testReporter.postMessage({
        log: true,
        message: JSON.stringify(arguments)
    });
} as any;
