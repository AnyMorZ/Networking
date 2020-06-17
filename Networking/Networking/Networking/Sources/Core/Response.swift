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
    
    struct Response<T> {
        
        public let result: Swift.Result<T, Error>
        
        public var request: URLRequest? {
            return dataResponse.request
        }
        
        public var response: HTTPURLResponse? {
            return dataResponse.response
        }
        
        public var data: Data? {
            return dataResponse.data
        }
        
        public var metrics: URLSessionTaskMetrics? {
            return dataResponse.metrics
        }
        
        private let dataResponse: AFDataResponse<T>
       
        init(dataResponse: AFDataResponse<T>, adapter: ResponseResultAdapter)  {
            self.dataResponse = dataResponse
            self.result = adapter.process(dataResponse.result.map({ $0 as Any })).flatMap({ val in
                if let v = val as? T {
                    return .success(v)
                }
                return .failure(AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
            })
        }
    }
}


// MARK: -  ResponseDataAdapter

public class ResponseDataAdapter: Alamofire.DataPreprocessor {
    
    required init() {
        
    }
    
    public func preprocess(_ data: Data) throws -> Data {
        return try process(data)
    }
    
    open func process(_ data: Data) throws -> Data {
        fatalError("subclass impl")
    }
}

public class PassthroughResponseDataAdapter: ResponseDataAdapter {
    public override func process(_ data: Data) throws -> Data {
        return data
    }
}

// MARK: - ResponseSerializer


open class ResponseSerializer<T>: Alamofire.ResponseSerializer {
    
    public var dataPreprocessor: DataPreprocessor = PassthroughPreprocessor()
    
    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> T {
        fatalError("subclass impl")
    }
}


open class JSONResponseSerializer: ResponseSerializer<Any> {
    
    /// `JSONSerialization.ReadingOptions` used when serializing a response.
    public let options: JSONSerialization.ReadingOptions
    
    public required init(options: JSONSerialization.ReadingOptions = .allowFragments) {
        self.options = options
    }
    
    open override func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> Any {
        fatalError("sub class implement!!!")
    }
}

open class DefaultJSONResponseSerializer: JSONResponseSerializer {
         
    open override func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> Any {
        guard error == nil else { throw error! }

        guard var data = data, !data.isEmpty else {
            guard emptyResponseAllowed(forRequest: request, response: response) else {
                throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
            }
            return NSNull()
        }
        do {
            data = try dataPreprocessor.preprocess(data)
        } catch {
            throw AFError.responseValidationFailed(reason: .dataFileNil)
        }
        do {
            return try JSONSerialization.jsonObject(with: data, options: options)
        } catch {
            throw AFError.responseSerializationFailed(reason: .jsonSerializationFailed(error: error))
        }
    }
}

open class BinaryResponseSerializer: ResponseSerializer<Data> {
    
    public required override init() {
        super.init()
    }
    
    open override func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> Data {
        fatalError("sub class implement!!!")
    }
}


open class DefaultBinaryResponseSerializer: BinaryResponseSerializer {
    
    open override func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> Data {
        guard error == nil else { throw error! }

        guard var data = data, !data.isEmpty else {
            guard emptyResponseAllowed(forRequest: request, response: response) else {
                throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
            }
            return Data()
        }
        
        do {
            data = try dataPreprocessor.preprocess(data)
        } catch {
            throw AFError.responseValidationFailed(reason: .dataFileNil)
        }

        return data
    }
}

// MARK: - ResponseResultAdapter

open class ResponseResultAdapter {
    
    public required init() {
        
    }
    
    open func process(_ result: Result<Any, AFError>) -> Result<Any, Error> {
        fatalError("subclass impl")
    }
}

public class PassthroughResponseResultAdapter: ResponseResultAdapter {
    
    public override func process(_ result: Result<Any, AFError>) -> Result<Any, Error> {
        switch result {
        case .failure(let e):
            return .failure(e)
        case .success(let v):
            return .success(v)
        }
    }
}
