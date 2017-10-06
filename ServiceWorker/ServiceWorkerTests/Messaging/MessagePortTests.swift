import XCTest
@testable import ServiceWorker
import JavaScriptCore

class MessagePortTests: XCTestCase {

    func testSendingAMessage() {
        let portOne = SWMessagePort()
        let portTwo = SWMessagePort()

        portOne.targetPort = portTwo

        var fired = false
        let listener = portTwo.addEventListener("message") { (ev: ExtendableMessageEvent) in

            let dict = ev.data as! [String: Any]

            XCTAssertEqual(dict["hello"] as? String, "there")
            fired = true
        }

        portOne.postMessage([
            "hello": "there"
        ])

        portTwo.start()

        XCTAssertTrue(fired)
    }

    func testAutoStartOnMessageSetter() {
        let portOne = SWMessagePort()
        let portTwo = SWMessagePort()

        portOne.targetPort = portTwo
        portTwo.targetPort = portOne

        let jsc = JSContext()!
        jsc.setObject(portTwo, forKeyedSubscript: "testPort" as NSCopying & NSObjectProtocol)
        portOne.postMessage(["hello": "there"])

        jsc.evaluateScript("""
            var fireResponse = null
            testPort.onmessage = function(e) {
                fireResponse = e.data.hello;
            }
        """)

        XCTAssertEqual(jsc.objectForKeyedSubscript("fireResponse")!.toString(), "there")
    }
}
