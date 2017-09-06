//
//  SharedResources.swift
//  HybridShared
//
//  Created by alastair.coote on 13/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

/// In order to share data between our notification extension and our main app, we have to use an app group.
/// This is a quick utility class to avoid having to type the app group name everywhere.
public class SharedResources {

    public static var appGroupName: String? {
        return SharedResources.appBundle?.object(forInfoDictionaryKey: "HYBRID_APP_GROUP") as? String
    }

    public static var appGroupStorage: URL? {
        guard let groupName = appGroupName else {
            return nil
        }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupName)?.appendingPathComponent("hybrid/")
    }

    /// Because we have content extensions, mainBundle() can sometimes return an extension
    /// rather than the app itself. This function detects that, and resets it, so we know for
    /// sure that we are always receiving the app bundle.
    ///
    /// - Returns: An NSBundle for the main hybrid app
    public static var appBundle: Bundle? {
        var bundle: Bundle? = Bundle.main
        if Bundle.main.bundleURL.pathExtension == "appex" {
            // Peel off two directory levels - MY_APP.app/PlugIns/MY_APP_EXTENSION.appex

            let backTwoURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()

            bundle = Bundle(url: backTwoURL)
        }
        return bundle
    }
}
