//
//  AppDelegate.swift
//  Example
//
//  Created by zhangbangjun on 2020/3/31.
//  Copyright © 2020 jun. All rights reserved.
//

import UIKit
import Networking

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var token: ReachabilityManager.Token?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        Network.pinger.ping(hostName: "www.baidu.com") { result in
            print(result)
        }.start()

        
        Network.requestJSON("https://api.ipify.org?format=json").start { response in
            switch response.result {
            case .failure(let error):
                print(error)
                break
            case .success(let jsonObj):
                print(jsonObj)
            }
        }
        
        Network.reachability.startListening()
        self.token = Network.reachability.register({ flags in
            let type = ReachabilityManager.parseNetworkType(flags)
            switch type {
            case .noNetwork:
                print("noNetwork")
            case .unknown:
                print("unknown")
            case .wifi:
                print("wifi")
            case .wwan(let w):
                print(w)
            }
        })
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

