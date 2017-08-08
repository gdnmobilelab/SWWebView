//
//  SWNavigationAction.swift
//  SWWebView
//
//  Created by alastair.coote on 07/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit

/// We can't manually create WKNavigationActions, so instead we have to do this
class SWNavigationAction : WKNavigationAction {
    
    fileprivate let _request:URLRequest
    override var request: URLRequest {
        get {
            return _request
        }
    }
    
    fileprivate let _sourceFrame: WKFrameInfo
    override var sourceFrame: WKFrameInfo {
        get {
            return self._sourceFrame
        }
    }
    
    fileprivate let _targetFrame: WKFrameInfo?
    override var targetFrame: WKFrameInfo? {
        get {
            return self._targetFrame
        }
    }
    
    fileprivate let _navigationType: WKNavigationType
    override var navigationType: WKNavigationType {
        get {
            return self._navigationType
        }
    }
    
    init(request: URLRequest, sourceFrame: WKFrameInfo, targetFrame: WKFrameInfo?, navigationType: WKNavigationType) {
        self._request = request
        self._sourceFrame = sourceFrame
        self._targetFrame = targetFrame
        self._navigationType = navigationType
        super.init()
    }
    
}
