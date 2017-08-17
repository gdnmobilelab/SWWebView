//
//  GlobalEventLog.swift
//  ServiceWorker
//
//  Created by alastair.coote on 10/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

/// Our webview representations of the API need to be able to reflect
/// changes made natively. So we have a "log" that classes like
/// ServiceWorkerContainer push to, allowing us to listen and forward
/// these details to our webview.
public class GlobalEventLog {

    fileprivate static var listeners = Set<NSObject>()

    public static func addListener<T>(_ toRun: @escaping (T) -> Void) -> Listener<T> {
        let wrapper = Listener(toRun)
        self.listeners.insert(wrapper)
        return wrapper
    }

    public static func removeListener<T>(_ listener: Listener<T>) {
        self.listeners.remove(listener)
    }

    public static func notifyChange<T>(_ target: T) {
        self.listeners.forEach { listener in

            if let correctType = listener as? Listener<T> {
                correctType.funcToRun(target)
            }
        }
    }
}

// Using NSObject to get around generic issues. Bad? Maybe.
public class Listener<T>: NSObject {

    let funcToRun: (T) -> Void

    init(_ funcToRun: @escaping (T) -> Void) {
        self.funcToRun = funcToRun
    }
}
