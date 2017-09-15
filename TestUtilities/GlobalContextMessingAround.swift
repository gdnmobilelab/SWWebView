//
//  GlobalContextMessingAround.swift
//  ServiceWorkerTests
//
//  Created by alastair.coote on 13/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import XCTest
import JavaScriptCore

class GlobalContextMessingAround: XCTestCase {
    
    let blah = "BLAH"

//    func testCreateGlobalContext() {
//        
//        let ctx = JSContext()!
//        
//        let toApply: [String: Any] = [
//            "hurr": "durr",
//            "blah": self.blah
//        ]
//        
//        let generator = { (obj:Any) -> @convention(block) () -> Any in
//            return {
//                return obj
//            }
//        }
//        
//        toApply.forEach { (key, val) in
//            ctx.globalObject.defineProperty(key, descriptor: [
//                "get": generator(val)
//            ])
//        }
//        
//        
//        
//        ctx.evaluateScript("debugger;")
//        
//    }
    
//    func testConvoluted() {
//
////        let blah: @convention(block) () -> String = {
////            return "durr"
////        }
////
////
//        var definition = kJSClassDefinitionEmpty;
//        definition.getProperty = { (ctx, obj, nameRef, exception) -> JSValueRef? in
//
//            return JSStringCreateWithCFString("durr" as CFString)
//
//
//        }
//
//        definition.getPropertyNames = { (ctx, obj, accumulator) in
//            JSPropertyNameAccumulatorAddName(accumulator, JSStringCreateWithCFString("hurr" as CFString))
//        }
//
//
//        var def = JSClassDefinition(version: 1, attributes: JSClassAttributes(kJSPropertyAttributeNone), className: "WorkerGlobalContext", parentClass: nil, staticValues: nil, staticFunctions: nil, initialize: nil, finalize: nil, hasProperty: nil, getProperty: { (ctx, obj, nameRef, exception) -> JSValueRef? in
//
//            return JSStringCreateWithCFString("durr" as CFString)
//
//
//        }, setProperty: nil, deleteProperty: nil, getPropertyNames: nil, callAsFunction: nil, callAsConstructor: nil, hasInstance: nil, convertToType: nil)
//
//        let cl = JSClassCreate(&definition)
//
//        let global = JSGlobalContextCreate
//        JSGlobalContextRetain(global)
//        let ctx = JSContext(jsGlobalContextRef: global!)!
//
//        ctx.evaluateScript("debugger")
//
//    }
}
