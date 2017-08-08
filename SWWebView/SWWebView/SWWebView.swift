//
//  SWWebView.swift
//  SWWebView
//
//  Created by alastair.coote on 07/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit
import ServiceWorker

public class SWWebView : WKWebView {
    
    static let ServiceWorkerScheme = "sw"
    
    public var serviceWorkerPermittedDomains: [String] = []
    var swNavigationDelegate:SWWebViewNavigationDelegate?
    
    var containerBridge: WebViewServiceWorkerBridge? = nil
    
    fileprivate var outerNavigationDelegate: WKNavigationDelegate?

    /// Because we're doing all sorts of weird things with URLs, we have two
    /// navigation delegates - one internal, that handles the URL mapping,
    /// and one external, that in theory is ignorant of this not being a
    /// WKWebView.
    override public var navigationDelegate: WKNavigationDelegate? {
        get {
            return self.outerNavigationDelegate
        }
        set (value) {
            self.outerNavigationDelegate = value
        }
    }
    
    fileprivate func addSWHooksToConfiguration(_ configuration: WKWebViewConfiguration) {
        
        let pathToJS = Bundle(for: SWWebView.self).bundleURL
            .appendingPathComponent("js-dist", isDirectory: true)
            .appendingPathComponent("runtime.js")
        
        let jsRuntimeSource:String
        
        do {
            jsRuntimeSource = try String(contentsOf: pathToJS)
        } catch {
            Log.error?("Could not load SWWebKit runtime JS. Quitting.")
            
            // There's something very fundamentally wrong with the app if this happens,
            // so we hard exit.
            fatalError()
        }
        
        let fullSource = """
            var SW_PROTOCOL = "\(SWWebView.ServiceWorkerScheme)";
            debugger;
        """ + jsRuntimeSource
        
        let userScript = WKUserScript(source: fullSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        
        configuration.userContentController.addUserScript(userScript)
        
        NSLog("waah")
//        let jsContents =
        
    }
    
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        self.addSWHooksToConfiguration(configuration)
        self.swNavigationDelegate = SWWebViewNavigationDelegate(for: self)
        self.containerBridge = WebViewServiceWorkerBridge(for: self)
        super.navigationDelegate = self.swNavigationDelegate
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func load(_ request: URLRequest) -> WKNavigation? {
        
        if request.url == nil {
            // not sure how this would happen, but still
            return super.load(request)
        }
        
        let transformedRequest = self.swNavigationDelegate!.makeServiceWorkerSuitableURLRequest(request)
        
        return super.load(transformedRequest)
        
    }
    
    
    /// We need to ensure that we return the non-SW scheme URL no matter what.
    public override var url: URL? {
        get {
            if let url = super.url {
                if url.scheme != SWWebView.ServiceWorkerScheme {
                    return url
                } else {
                    return self.swNavigationDelegate!.makeNonServiceWorker(url: url)
                }
            } else {
                return nil
            }
        }
    }
    
}
