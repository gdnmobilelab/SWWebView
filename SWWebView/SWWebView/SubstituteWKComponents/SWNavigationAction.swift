import Foundation
import WebKit

/// We can't manually create WKNavigationActions, so instead we have to do this
class SWNavigationAction: WKNavigationAction {

    fileprivate let _request: URLRequest
    override var request: URLRequest {
        return self._request
    }

    fileprivate let _sourceFrame: WKFrameInfo
    override var sourceFrame: WKFrameInfo {
        return self._sourceFrame
    }

    fileprivate let _targetFrame: WKFrameInfo?
    override var targetFrame: WKFrameInfo? {
        return self._targetFrame
    }

    fileprivate let _navigationType: WKNavigationType
    override var navigationType: WKNavigationType {
        return self._navigationType
    }

    init(request: URLRequest, sourceFrame: WKFrameInfo, targetFrame: WKFrameInfo?, navigationType: WKNavigationType) {
        self._request = request
        self._sourceFrame = sourceFrame
        self._targetFrame = targetFrame
        self._navigationType = navigationType
        super.init()
    }
}
