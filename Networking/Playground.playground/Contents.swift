import UIKit
import Networking


Network.request("https://www.baidu.com").make().responseJSON { response in
    debugPrint(response)
}

Network.request("http://dl.360safe.com/wifispeed/wifispeed.test").make().responseBinaryData { response in
    if let metrics = response.metrics {
        debugPrint(metrics)
    }
}

