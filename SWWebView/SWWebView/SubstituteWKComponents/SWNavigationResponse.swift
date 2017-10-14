import Foundation
import WebKit

class SWNavigationResponse: WKNavigationResponse {

    fileprivate let _canShowMIMEType: Bool
    override var canShowMIMEType: Bool {
        return self._canShowMIMEType
    }

    fileprivate let _isForMainFrame: Bool
    override var isForMainFrame: Bool {
        return self._isForMainFrame
    }

    fileprivate let _response: URLResponse
    override var response: URLResponse {
        return self._response
    }

    init(response: URLResponse, isForMainFrame: Bool, canShowMIMEType: Bool) {
        self._response = response
        self._isForMainFrame = isForMainFrame
        self._canShowMIMEType = canShowMIMEType
    }
}
