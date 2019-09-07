//
//  Response.swift
//  Networking
//
//  Created by zhangbangjun on 2019/9/5.
//  Copyright © 2019 zhangbangjun. All rights reserved.
//

import Foundation
import Alamofire

// MARK: - Response

public extension Network {
    
    struct Response<Value> {
        
        public let result: Swift.Result<Value, Error>
        
        public var request: URLRequest? {
            return dataResponse.request
        }
        
        public var response: HTTPURLResponse? {
            return dataResponse.response
        }
        
        public var data: Data? {
            return dataResponse.data
        }
        
        public var timeline: Timeline {
            return dataResponse.timeline
        }
      
        public var metrics: AnyObject? {
            return dataResponse.metrics
        }
        
        private let dataResponse: Alamofire.DataResponse<Value>
       
        public init<T: MyResponseProcessor>(dataResponse: Alamofire.DataResponse<T.Value>, processor: T.Type) where T.Value == Value {
            self.dataResponse = dataResponse
            self.result = processor.process(response: dataResponse)
        }
    }
}


// MARK: - Serializer

extension Network.Request {
    
    /// Creates a response serializer that returns a JSON object result type constructed from the response data using
    /// `JSONSerialization` with the specified reading options.
    ///
    /// - parameter options: The JSON serialization reading options. Defaults to `.allowFragments`.
    ///
    /// - returns: A JSON object response serializer.
    public static func jsonResponseSerializer(
        options: JSONSerialization.ReadingOptions = .allowFragments)
        -> DataResponseSerializer<Any>
    {
        return DataResponseSerializer { _, response, data, error in
            return Alamofire.DataRequest.serializeResponseJSON(options: options, response: response, data: data, error: error)
        }
    }
}


// MARK: - Processor

extension Network {
    
    /// 统计等处理
    fileprivate static func didReceivceResponse<T>(_ response: DataResponse<T>, name: T.Type) {
//        guard let request = response.request, let url = request.url else {
//            return
//        }
//        switch response.result {
//        case .failure(_):
//            break
//        case .success(_):
//            break
//        }
//        if let metrics = response.metrics {
//            debugPrint(metrics)
//        }
    }
}

public protocol MyResponseProcessor {
    associatedtype Value
    static func process(response: Alamofire.DataResponse<Value>) -> Swift.Result<Value, Error>
}


public class DefaultResponseProcessor<T>: MyResponseProcessor {
    
    public typealias Value = T
    
    public static func process(response: DataResponse<T>) -> Swift.Result<T, Error> {
        defer {
            Network.didReceivceResponse(response, name: T.self)
        }
        switch response.result {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(error)
        }
    }
}

public class JSONResponseProcessor<T>: MyResponseProcessor {
    
    public typealias Value = T
    
    public static func process(response: DataResponse<T>) -> Swift.Result<T, Error> {
        defer {
            Network.didReceivceResponse(response, name: T.self)
        }
        switch response.result {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(error)
        }
    }
}
