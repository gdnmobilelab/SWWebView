//
//  GlobalVariableProvider.swift
//  ServiceWorker
//
//  Created by alastair.coote on 15/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

// I'm seeing weird issues with memory holds when we add objects directly to a
// JSContext's global object. So instead we use this and defineProperty to map
// properties without directly attaching them to the object.
class GlobalVariableProvider {

    static let variableMaps = NSMapTable<JSContext, NSMutableDictionary>(keyOptions: NSPointerFunctions.Options.weakMemory, valueOptions: NSPointerFunctions.Options.strongMemory)

    fileprivate static func getDictionary(forContext context: JSContext) -> NSDictionary {
        if let existing = variableMaps.object(forKey: context) {
            return existing
        }

        let newDictionary = NSMutableDictionary()
        variableMaps.setObject(newDictionary, forKey: context)
        return newDictionary
    }

    fileprivate static func createPropertyAccessor(for name: String) -> @convention(block) () -> Any? {
        return {

            guard let ctx = JSContext.current() else {
                Log.error?("Tried to use a JS property accessor with no JSContext. Should never happen")
                return nil
            }

            let dict = GlobalVariableProvider.getDictionary(forContext: ctx)
            return dict[name]
        }
    }

    static func destroy(forContext context: JSContext) {

        if let dict = variableMaps.object(forKey: context) {
            // Not really sure if this makes a difference, but we might as well
            // delete the property callbacks we created.
            dict.allKeys.forEach { key in
                if let keyAsString = key as? String {
                    context.globalObject.deleteProperty(keyAsString)
                }
            }
        }

        if context.globalObject.hasProperty("self") {
            context.globalObject.deleteProperty("self")
        }

        self.variableMaps.removeObject(forKey: context)
    }

    /// A special case so we don't need to hold a reference to the global object
    static func addSelf(to context: JSContext) {
        context.globalObject.defineProperty("self", descriptor: [
            "get": {
                JSContext.current().globalObject
            } as @convention(block) () -> Any?
        ])
    }

    static func add(variable: Any, to context: JSContext, withName name: String) {

        let dictionary = GlobalVariableProvider.getDictionary(forContext: context)
        dictionary.setValue(variable, forKey: name)

        context.globalObject.defineProperty(name, descriptor: [
            "get": createPropertyAccessor(for: name)
        ])
    }

    static func add(missingPropertyWithError error: String, to context: JSContext, withName name: String) {

        context.globalObject.defineProperty(name, descriptor: [
            "get": {
                if let ctx = JSContext.current() {
                    let err = JSValue(newErrorFromMessage: error, in: ctx)
                    ctx.exception = err
                }
            } as @convention(block) () -> Void
        ])
    }
}
