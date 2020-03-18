//
//  HDQNTool.swift
//  App
//
//  Created by Damon on 2020/3/17.
//

import Vapor
import Crypto
import Foundation

public final class Res_QNDataConfig: Content {
    public var token = ""      //上传的token
    public var fileKey = ""   //上传的文件名字
    public init() {}
}

public class HDQNTool {
    private var accessKey = ""
    private var secretKey = ""
    
    public required init(accessKey: String, secretKey: String) {
        self.accessKey = accessKey
        self.secretKey = secretKey
    }
    
    @discardableResult
    public func uploadFile(_ req: Request, bucket: String, fileName: String) throws -> Future<Res_QNDataConfig> {
        //当前时间戳
        let currentTimeStamp : Int = Int(Date().timeIntervalSince1970)
        //默认4小时有效期
        let futureTimeStamp = currentTimeStamp + 3600
        //上传策略
        let putPolicy = ["scope": "\(bucket):\(fileName)", "deadline": futureTimeStamp] as [String : Any]
        //base64编码
        let putPolicyJsonData = try JSONSerialization.data(withJSONObject: putPolicy)
        let encodedPutPolicy = putPolicyJsonData.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        //生成sign
        
        let sign = try HMAC.SHA1.authenticate(encodedPutPolicy, key: self.secretKey)
        let encodedSign = sign.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        //最终的token
        let uploadToken = self.accessKey + ":" + encodedSign + ":" + encodedPutPolicy
        
        //生成验证信息
        let res_QNDataConfig = Res_QNDataConfig()
        res_QNDataConfig.token = uploadToken
        res_QNDataConfig.fileKey = fileName
        return req.future(res_QNDataConfig)
    }
    
    @discardableResult
    public func deleteFile(_ req: Request, bucket: String, fileName: String) throws -> Future<UInt> {
        let entry = "\(bucket):\(fileName)"
        let entryData = entry.data(using: String.Encoding.utf8) ?? Data()
        
        let encodedEntryURI = entryData.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        //发送删除请求
        let url = "http://rs.qbox.me/delete/" + encodedEntryURI
        let authorization = try self.p_getAuthorization(urlString: "/delete/" + encodedEntryURI + "\n")
        
        let client = try req.make(Client.self)
        let request = Request(http: HTTPRequest(method: HTTPMethod.POST, url: URL(string: url)!, headers: HTTPHeaders([("Authorization" , "QBox " + authorization), ("Content-Type", "application/x-www-form-urlencoded")]), body: HTTPBody(string:"")), using: req)
        return client.send(request).map { (response) -> UInt in
            print(response)
            return response.http.status.code
        }
    }
    
    private func p_getAuthorization(urlString: String) throws -> String {
        let signingStr = try HMAC.SHA1.authenticate(urlString, key: self.secretKey)
        let encodedSign = signingStr.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        let token = self.accessKey + ":" + encodedSign
        return token
    }
}
