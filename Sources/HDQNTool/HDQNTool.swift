//
//  HDQNTool.swift
//  App
//
//  Created by Damon on 2020/3/17.
//

import Vapor
import Crypto

public final class Res_QNDataConfig: Content {
    var token = ""      //上传的token
    var fileKey = ""   //上传的文件名字
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
    public func uploadFile(_ req: Request, fileName: String) throws -> Future<Res_QNDataConfig> {
        //当前时间戳
        let currentTimeStamp : Int = Int(Date().timeIntervalSince1970)
        //默认4小时有效期
        let futureTimeStamp = currentTimeStamp + 3600
        //上传策略
        let putPolicy = ["scope": "lazypigflarum:\(fileName)", "deadline": futureTimeStamp] as [String : Any]
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
}
