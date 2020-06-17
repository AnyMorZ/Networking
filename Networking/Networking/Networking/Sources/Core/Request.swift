//
//  Request.swift
//  Networking
//
//  Created by zhangbangjun on 2019/9/5.
//  Copyright © 2019 zhangbangjun. All rights reserved.
//

import Foundation
import Alamofire

extension Dictionary {
    
    static func +=(lhs: inout [Key: Value], rhs: [Key: Value]) {
        rhs.forEach({ lhs[$0] = $1})
    }
    
    static func +=(lhs: inout [Key: Value], rhs: [Key: Value]?) {
        if let r = rhs {
            r.forEach({lhs[$0] = $1})
        }
    }
}

public struct RequestConvertible: Alamofire.URLRequestConvertible {
    let url: Alamofire.URLConvertible
    let method: Alamofire.HTTPMethod
    let parameters: Alamofire.Parameters?
    let encoding: Alamofire.ParameterEncoding
    let headers: Alamofire.HTTPHeaders?

    public func asURLRequest() throws -> URLRequest {
        let request = try URLRequest(url: url, method: method, headers: headers)
        return try encoding.encode(request, with: parameters)
    }
}

public enum ParameterEncoding {
    case url
    case gzip
    case json
    case custom(Alamofire.ParameterEncoding)
}

// MARK: - HTTPRequestMaker

open class HTTPRequestMaker {
    
    let urlStr: String
    private(set) var method: HTTPMethod = .get
    private(set) var includeCommonParameters = true
    private(set) var parameters: [String: Any]? = nil
    private(set) var headers: HTTPHeaders? = nil
    private(set) var parameterEncoding: ParameterEncoding = .url
    /// The queue on which the completion handler is dispatched. `.main` by default.
    private(set) var callbackQueue: DispatchQueue = .main

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
    open func parameterEncoding(_ parameterEncoding: ParameterEncoding) -> Self {
        self.parameterEncoding = parameterEncoding
        return self
    }
    
    @discardableResult
    open func callbackQueue(_ queue: DispatchQueue) -> Self {
        self.callbackQueue = queue
        return self
    }

    func query(_ parameters: [String: Any]) -> String {
        var components: [(String, String)] = []
        
        for key in parameters.keys.sorted(by: <) {
            let value = parameters[key]!
            components += URLEncoding.default.queryComponents(fromKey: key, value: value)
        }
        return components.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
    }
    
    var request: RequestConvertible {
        var requestURLStr = urlStr
        
        var encoding: Alamofire.ParameterEncoding
        switch self.parameterEncoding {
        case .url:
            encoding = URLEncoding.default
        case .json:
            encoding = JSONEncoding.default
        case .gzip:
            encoding = GZipEncoding.default
        case .custom(let cm):
            encoding = cm
        }
        
        var commonParameters = [String: Any]()
        if includeCommonParameters {
            commonParameters += Network.commonParameters
            commonParameters += Network.dynamicCommonParameters?()
        }
        
        var parms = [String: Any]()
        if method != .post {
            parms += commonParameters
            parms += parameters
        } else {
            if !commonParameters.isEmpty {
                let queryStr = query(commonParameters)
                if urlStr.contains("?") {
                    if urlStr.hasSuffix("&") || urlStr.hasSuffix("?") {
                        requestURLStr = "\(urlStr)\(queryStr)"
                    } else {
                        requestURLStr = "\(urlStr)&\(queryStr)"
                    }
                } else {
                    requestURLStr = "\(urlStr)?\(queryStr)"
                }
            }
            parms += parameters
        }
        return RequestConvertible(url: requestURLStr,
                                  method: method,
                                  parameters: parms,
                                  encoding: encoding,
                                  headers: headers)
    }
}

// MARK: - HTTPDataRequest

public extension Network {

    static func request(_ urlStr: String) -> HTTPDataRequestMaker {
        return HTTPDataRequestMaker(urlStr: urlStr)
    }
    
    static func requestData(_ urlStr: String) -> HTTPBinaryDataRequestMaker {
        return HTTPBinaryDataRequestMaker(urlStr: urlStr)
    }
    
    static func requestJSON(_ urlStr: String) -> HTTPJSONDataRequestMaker {
        return HTTPJSONDataRequestMaker(urlStr: urlStr)
    }
}

/// emmm...., 以后再找一个更加优雅的方式，不需要重写方法
open class HTTPDataRequestMaker: HTTPRequestMaker {
    
    /// Closure type executed when monitoring the download progress of a request.
    private(set) var progressHandler: Alamofire.Request.ProgressHandler?
    
    @discardableResult
    open func progressHandler(_ handler: Alamofire.Request.ProgressHandler?) -> Self {
        self.progressHandler = handler
        return self
    }
    
    @discardableResult
    open override func method(_ method: HTTPMethod) -> Self {
        super.method(method)
        return self
    }
    
    @discardableResult
    open override func includeCommonParameters(_ include: Bool) -> Self {
        super.includeCommonParameters(include)
        return self
    }
    
    @discardableResult
    open override func parameters(_ parameters: [String: Any]) -> Self {
        super.parameters(parameters)
        return self
    }
    
    @discardableResult
    open override func headers(_ headers: HTTPHeaders) -> Self {
        super.headers(headers)
        return self
    }
    
    @discardableResult
    open override func parameterEncoding(_ parameterEncoding: ParameterEncoding) -> Self {
        super.parameterEncoding(parameterEncoding)
        return self
    }
    
    @discardableResult
    open override func callbackQueue(_ queue: DispatchQueue) -> Self {
        super.callbackQueue(queue)
        return self
    }

    func makeRequest() -> DataRequest {
        return Network.session.request(request, interceptor: nil)
    }
    
    public func start<T>(dataAdapter: ResponseDataAdapter,
                         serializer: ResponseSerializer<T>,
                         resultAdapter: ResponseResultAdapter,
                         completionHandler: @escaping (Network.Response<T>) -> Void)
        -> DataRequest
    {
        let request = self.makeRequest()
        if let progressHandler = self.progressHandler {
            request.downloadProgress(queue: .main, closure: progressHandler)
        }
        serializer.dataPreprocessor = dataAdapter
        request.response(queue: callbackQueue, responseSerializer: serializer) { (dataResponse) in
            let response = Network.Response(dataResponse: dataResponse, adapter: resultAdapter)
            completionHandler(response)
        }
        return request
    }
}

open class HTTPJSONDataRequestMaker: HTTPDataRequestMaker {
    
    /// The JSON serialization reading options. `.allowFragments` by default.
    private(set) var options: JSONSerialization.ReadingOptions = .allowFragments

    @discardableResult
    open func options(_ options: JSONSerialization.ReadingOptions) -> Self {
        self.options = options
        return self
    }
    
    @discardableResult
    open override func method(_ method: HTTPMethod) -> Self {
        super.method(method)
        return self
    }
    
    @discardableResult
    open override func includeCommonParameters(_ include: Bool) -> Self {
        super.includeCommonParameters(include)
        return self
    }
    
    @discardableResult
    open override func parameters(_ parameters: [String: Any]) -> Self {
        super.parameters(parameters)
        return self
    }
    
    @discardableResult
    open override func headers(_ headers: HTTPHeaders) -> Self {
        super.headers(headers)
        return self
    }
    
    @discardableResult
    open override func parameterEncoding(_ parameterEncoding: ParameterEncoding) -> Self {
        super.parameterEncoding(parameterEncoding)
        return self
    }
    
    @discardableResult
    open override func callbackQueue(_ queue: DispatchQueue) -> Self {
        super.callbackQueue(queue)
        return self
    }

    /// Start the Request
    ///
    /// - parameter completionHandler: A closure to be executed once the request has finished.
    ///
    /// - Returns: The request.
    @discardableResult
    public func start(completionHandler: @escaping (Network.Response<Any>) -> Void) -> DataRequest {
        let dataAdapter = Network.dataAdapter()
        let serializer = Network.jsonSerializer(with: options)
        let resultAdapter = Network.resultAdapter()
        return start(dataAdapter: dataAdapter,
                     serializer: serializer,
                     resultAdapter: resultAdapter,
                     completionHandler: completionHandler)
    }
}

open class HTTPBinaryDataRequestMaker: HTTPDataRequestMaker {
    
    @discardableResult
    open override func method(_ method: HTTPMethod) -> Self {
        super.method(method)
        return self
    }
    
    @discardableResult
    open override func includeCommonParameters(_ include: Bool) -> Self {
        super.includeCommonParameters(include)
        return self
    }
    
    @discardableResult
    open override func parameters(_ parameters: [String: Any]) -> Self {
        super.parameters(parameters)
        return self
    }
    
    @discardableResult
    open override func headers(_ headers: HTTPHeaders) -> Self {
        super.headers(headers)
        return self
    }
    
    @discardableResult
    open override func parameterEncoding(_ parameterEncoding: ParameterEncoding) -> Self {
        super.parameterEncoding(parameterEncoding)
        return self
    }
    
    @discardableResult
    open override func callbackQueue(_ queue: DispatchQueue) -> Self {
        super.callbackQueue(queue)
        return self
    }


    /// Start the Request
    ///
    /// - parameter completionHandler: A closure to be executed once the request has finished.
    ///
    /// - Returns:             The request.
    @discardableResult
    public func start(completionHandler: @escaping (Network.Response<Data>) -> Void) -> DataRequest {
        let dataAdapter = Network.dataAdapter()
        let serializer = Network.binarySerializer()
        let resultAdapter = Network.resultAdapter()
        return start(dataAdapter: dataAdapter,
                     serializer: serializer,
                     resultAdapter: resultAdapter,
                     completionHandler: completionHandler)
    }
}


// MARK: - HTTPUploadRequestMaker

public extension Network {

    static func upload(_ urlStr: String) -> HTTPUploadRequestMaker {
        return HTTPUploadRequestMaker(urlStr: urlStr)
    }
}

open class HTTPUploadRequestMaker: HTTPRequestMaker {
    
    private(set) var multipartFormData = MultipartFormData(fileManager: .default)
    
    /// The JSON serialization reading options. `.allowFragments` by default.
    private(set) var options: JSONSerialization.ReadingOptions = .allowFragments
    

    @discardableResult
    open func options(_ options: JSONSerialization.ReadingOptions) -> Self {
       self.options = options
       return self
    }
    
    @discardableResult
    open override func method(_ method: HTTPMethod) -> Self {
        super.method(method)
        return self
    }
    
    @discardableResult
    open override func includeCommonParameters(_ include: Bool) -> Self {
        super.includeCommonParameters(include)
        return self
    }
    
    @discardableResult
    open override func parameters(_ parameters: [String: Any]) -> Self {
        super.parameters(parameters)
        return self
    }
    
    @discardableResult
    open override func headers(_ headers: HTTPHeaders) -> Self {
        super.headers(headers)
        return self
    }
    
    @discardableResult
    open override func parameterEncoding(_ parameterEncoding: ParameterEncoding) -> Self {
        super.parameterEncoding(parameterEncoding)
        return self
    }
    
    @discardableResult
    open override func callbackQueue(_ queue: DispatchQueue) -> Self {
        super.callbackQueue(queue)
        return self
    }
    
    @discardableResult
    open func progressHandler(_ handler: Alamofire.Request.ProgressHandler?) -> Self {
        self.progressHandler = handler
        return self
    }
    
    /// Closure type executed when monitoring the upload progress of a request.
    private(set) var progressHandler: Alamofire.Request.ProgressHandler?
    
    open func makeRequest() -> UploadRequest {
        return Network.session.upload(multipartFormData: multipartFormData, with: request)
    }
        
    public func multipartFormData(_ append: (MultipartFormData) -> Void ) -> Self {
        append(multipartFormData)
        return self
    }
}

extension HTTPUploadRequestMaker {
    
    /// Start the Request
    ///
    /// - parameter dataAdapter: Type used to process `Data` before it handled by a serializer.
    /// - parameter serializer: The response serializer responsible for serializing the request, response, and data.
    /// - parameter resultAdapter: Type used to process `Result` after serializer.
    /// - parameter completionHandler:  The code to be executed once the request has finished.
    ///
    /// - returns: The request.
    public func start<T>(dataAdapter: ResponseDataAdapter,
                         serializer: ResponseSerializer<T>,
                         resultAdapter: ResponseResultAdapter,
                         completionHandler: @escaping (Network.Response<T>) -> Void)
        -> DataRequest
    {
        let request = self.makeRequest()
        if let progressHandler = self.progressHandler {
            request.uploadProgress(queue: .main, closure: progressHandler)
        }
        serializer.dataPreprocessor = dataAdapter
        request.response(queue: callbackQueue, responseSerializer: serializer) { (dataResponse) in
            let response = Network.Response(dataResponse: dataResponse, adapter: resultAdapter)
            completionHandler(response)
        }
        return request
    }
}

extension HTTPUploadRequestMaker {
           
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - options:           The JSON serialization reading options. `.allowFragments` by default.
    ///   - completionHandler: A closure to be executed once the request has finished.
    ///
    /// - Returns:             The request.
    @discardableResult
    public func responseJSON(completionHandler: @escaping (Network.Response<Any>) -> Void) -> DataRequest {
        let dataAdapter = Network.dataAdapter()
        let serializer = Network.jsonSerializer()
        let resultAdapter = Network.resultAdapter()
        return start(dataAdapter: dataAdapter, serializer: serializer, resultAdapter: resultAdapter, completionHandler: completionHandler)
    }
}
