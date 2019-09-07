//
//  Session.swift
//  Networking
//
//  Created by zhangbangjun on 2019/9/5.
//  Copyright © 2019 zhangbangjun. All rights reserved.
//

import Foundation
import Alamofire

extension Network {
    
    static var sessionManager: Alamofire.SessionManager = {
        var configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15;
        configuration.timeoutIntervalForResource = 350;
        let sessionManager = Alamofire.SessionManager(configuration: configuration)
        return sessionManager
    }()
}
