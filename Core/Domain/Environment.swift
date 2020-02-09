///
//  Core
//
//  Copyright © 2018 mkerekes. All rights reserved.
//

import Foundation

public enum Environment: String {
    case prod = "https://api.prod.network"
    case dev = "https://api.dev01.cloud"
    case stage = "https://api.stage01.cloud"
    
    static let key = "Environment"
    public var baseUrl: URL {
        return URL(string: self.rawValue)!
    }
    
    init(defaults: DefaultSettings){
        guard let readSettings = defaults.string(forKey: Environment.key),
            let env = Environment(rawValue: readSettings) else {
                
                defaults.set(Environment.prod.rawValue, forKey: Environment.key)
                defaults.synchronize()
                self = Environment.prod
                return
        }
        self = env
        defaults.synchronize()
    }
}