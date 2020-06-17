import UIKit
import Networking
import PlaygroundSupport

var str = "Hello, playground"


Network.pinger.ping(hostName: "www.baidu.com") { result in
    debugPrint(result)
}.start()

