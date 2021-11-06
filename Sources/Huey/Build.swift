//
//  File.swift
//  
//
//  Created by Cameron Jackson on 11/5/21.
//

import Foundation

enum Build {
    
    case debug
    case appStore
    
    static var currentBuild: Build {
        #if DEBUG
        return .debug
        #else
        return .appStore
        #endif
    }
    
    static var appVersion: String {
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return "unkown"
        }
        
        return appVersion
    }
}
