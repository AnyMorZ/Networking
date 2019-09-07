//
//  Request.swift
//  Networking
//
//  Created by zhangbangjun on 2019/9/5.
//  Copyright © 2019 zhangbangjun. All rights reserved.
//

import Foundation
import Alamofire

public extension Network {

    static func request(_ urlStr: String) -> RequestDescriptor {
        return RequestDescriptor(urlStr: urlStr)
    }
    
    class RequestDescriptor {
        
        let urlStr: String
        private(set) var method: HTTPMethod = .get
        private(set) var includeCommonParameters = true
        private(set) var parameters: [String: Any]? = nil
        private(set) var headers: HTTPHeaders? = nil
        private(set) var retryTimes: UInt = 0
        private(set) var encoding: Request.ParameterEncoding = .url
        
        init(urlStr: String) {
            self.urlStr = urlStr
        }
        
        @discardableResult
        open func method(_ method: HTTPMethod) -> Self {
            self.method = method
            return self
        }
        
        @discardableResult
        open func includeCommonParameters(_ include: Bool) -> Self {
            self.includeCommonParameters = include
            return self
        }
        
        @discardableResult
        open func parameters(_ parameters: [String: Any]) -> Self {
            self.parameters = parameters
            return self
        }
        
        @discardableResult
        open func headers(_ headers: HTTPHeaders) -> Self {
            self.headers = headers
            return self
        }
        
        @discardableResult
        open func retry(_ retryTimes: UInt) -> Self {
            self.retryTimes = retryTimes
            return self
        }
        
        @discardableResult
        open func encoding(_ encoding: Request.ParameterEncoding) -> Self {
            self.encoding = encoding
            return self
        }

        open func make() -> Request {
            let requestURLStr = urlStr
            
            var encoding: Alamofire.ParameterEncoding
            switch self.encoding {
            case .url:
                encoding = URLEncoding.default
            case .json:
                encoding = JSONEncoding.default
            case .propertyList:
                encoding = PropertyListEncoding.default
            case .custom(let ed):
                encoding = ed
            }
            
            let dataRequest =
                Network.sessionManager.request(requestURLStr,
                                               method: method,
                                               parameters: parameters,
                                               encoding: encoding,
                                               headers: headers)
            
            let request = Request(dataRequest: dataRequest)
            request.retryTimes = retryTimes
            return request
        }
    }
    
    class Request {
        
        public enum ParameterEncoding {
            case url
            case json
            case propertyList
            case custom(Alamofire.ParameterEncoding)
        }
        
        private var dataRequest: DataRequest
        
        fileprivate var retryTimes: UInt = 0
        
        init(dataRequest: DataRequest) {
            self.dataRequest = dataRequest
        }
        
        public func cancel() {
            dataRequest.cancel()
        }
        
        public func pause() {
            dataRequest.suspend()
        }
        
        public func resume() {
            dataRequest.resume()
        }
        
        /// Adds a handler to be called once the request has finished.
        ///
        /// - parameter responseSerializer: The response serializer responsible for serializing the request, response,
        ///                                 and data.
        /// - parameter completionHandler:  The code to be executed once the request has finished.
        ///
        /// - returns: The request.
        @discardableResult
        public func response<T: DataResponseSerializerProtocol>(
            responseSerializer: T,
            completionHandler: @escaping (DataResponse<T.SerializedObject>) -> Void)
            -> Self
        {
            dataRequest.response(queue: .main,
                                 responseSerializer: responseSerializer,
                                 completionHandler: completionHandler)
            return self
        }
    }
}


// MARK: - JSON

extension Network.Request {
    
    @discardableResult
    public func responseJSON(completionHandler: @escaping (Network.Response<Any>) -> Void) -> Self {
        return response(serializer: Network.Request.jsonResponseSerializer(),
                        processor: JSONResponseProcessor<Any>.self,
                        completionHandler: completionHandler)
    }
}


// MARK: - BinaryData

extension Network.Request {
    
    public func downloadProgress(queue: DispatchQueue = DispatchQueue.main, closure: @escaping Alamofire.Request.ProgressHandler) -> Self {
        dataRequest.downloadProgress(queue: queue, closure: closure)
        return self
    }
    
    @discardableResult
    public func responseBinaryData(completionHandler: @escaping (Network.Response<Data>) -> Void) -> Self {
        return response(serializer: DataRequest.dataResponseSerializer(),
                        processor: DefaultResponseProcessor<Data>.self,
                        completionHandler: completionHandler)
    }
}

// MARK: -  Customize

extension Network.Request {
    
    @discardableResult
    public func response<T: MyResponseProcessor>(
        serializer: DataResponseSerializer<T.Value>,
        processor: T.Type,
        completionHandler: @escaping (Network.Response<T.Value>) -> Void
    ) -> Self {
        return response(responseSerializer: serializer) {
            completionHandler(Network.Response(dataResponse: $0, processor: processor))
        }
    }
}
