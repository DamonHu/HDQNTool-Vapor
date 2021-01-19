//
//  HDQNTool.swift
//  App
//
//  Created by Damon on 2020/3/17.
//

import Vapor

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
    public func uploadFile(_ req: Request, bucket: String, fileName: String) throws -> EventLoopFuture<Res_QNDataConfig> {
        //当前时间戳
        let currentTimeStamp : Int = Int(Date().timeIntervalSince1970)
        //默认4小时有效期
        let EventLoopFutureTimeStamp = currentTimeStamp + 3600
        //上传策略
        let putPolicy = ["scope": "\(bucket):\(fileName)", "deadline": EventLoopFutureTimeStamp] as [String : Any]
        //base64编码
        let putPolicyJsonData = try JSONSerialization.data(withJSONObject: putPolicy)
        let encodedPutPolicy = putPolicyJsonData.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        //生成sign
        let key = SymmetricKey(data: Data(self.secretKey.utf8))

        let sign = Data(HMAC<Insecure.SHA1>.authenticationCode(for: Data(encodedPutPolicy.utf8), using: key))
        let encodedSign = sign.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        //最终的token
        let uploadToken = self.accessKey + ":" + encodedSign + ":" + encodedPutPolicy

        //生成验证信息
        let res_QNDataConfig = Res_QNDataConfig()
        res_QNDataConfig.token = uploadToken
        res_QNDataConfig.fileKey = fileName

        return req.eventLoop.future(res_QNDataConfig)
    }

    @discardableResult
    public func deleteFile(_ req: Request, bucket: String, fileName: String) throws -> EventLoopFuture<UInt> {
        let entry = "\(bucket):\(fileName)"
        let entryData = entry.data(using: String.Encoding.utf8) ?? Data()

        let encodedEntryURI = entryData.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        //发送删除请求
        let url = "http://rs.qbox.me/delete/" + encodedEntryURI
        let authorization = try self.p_getAuthorization(urlString: "/delete/" + encodedEntryURI + "\n")

        return req.client.post(URI(string: url), headers: HTTPHeaders([("Authorization" , "QBox " + authorization), ("Content-Type", "application/x-www-form-urlencoded")])) { (req) in

        }.map { (res) -> (UInt) in
            return res.status.code
        }
    }

    private func p_getAuthorization(urlString: String) throws -> String {
        //生成sign
        let key = SymmetricKey(data: Data(self.secretKey.utf8))
        let sign = Data(HMAC<Insecure.SHA1>.authenticationCode(for: Data(urlString.utf8), using: key))
        let encodedSign = sign.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        let token = self.accessKey + ":" + encodedSign
        return token
    }
}
