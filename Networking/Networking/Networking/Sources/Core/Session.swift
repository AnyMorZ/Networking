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
   
    
    static var session: Alamofire.Session = {
        var configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15;
        configuration.timeoutIntervalForResource = 350;
        let session = Alamofire.Session(configuration: configuration)
        return session
    }()
    
    public static var commonParameters: [String: Any]?
    public static var dynamicCommonParameters: (() -> [String: Any])?
    
    public static var dataAdapterType: ResponseDataAdapter.Type = PassthroughResponseDataAdapter.self
    public static var jsonResponseSerializerType: JSONResponseSerializer.Type = DefaultJSONResponseSerializer.self
    public static var binaryResponseSerializerType: BinaryResponseSerializer.Type = DefaultBinaryResponseSerializer.self
    public static var responseResultAdapterType: ResponseResultAdapter.Type = PassthroughResponseResultAdapter.self
}

extension Network {
    
    public static func dataAdapter() -> ResponseDataAdapter  {
        return dataAdapterType.init()
    }
    
    public static func jsonSerializer(with option: JSONSerialization.ReadingOptions = .allowFragments) -> JSONResponseSerializer {
        return jsonResponseSerializerType.init(options: option)
    }
    
    public static func binarySerializer() -> BinaryResponseSerializer {
        return binaryResponseSerializerType.init()
    }
    
    public static func resultAdapter() -> ResponseResultAdapter {
        return responseResultAdapterType.init()
    }
}
