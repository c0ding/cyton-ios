//
//  TokenModel.swift
//  Neuron
//
//  Created by XiaoLu on 2018/7/2.
//  Copyright © 2018年 cryptape. All rights reserved.
//

import Foundation
import RealmSwift

enum TokenType: String {
    case ether
    case erc20
    case appChain
    case appChainErc20
}

class TokenModel: Object, Decodable {
    @objc dynamic var name = ""
    @objc dynamic var iconUrl: String? = ""
    @objc dynamic var address = ""
    @objc dynamic var decimals = 18
    @objc dynamic var symbol = ""
    @objc dynamic var chainName: String? = ""
    @objc dynamic var chainId = ""
    @objc dynamic var chainHosts = "" // manifest.json chainSet.values.first
    @objc dynamic var identifier = UUID().uuidString // primary key == UUID

    // defaults false, eth and RPC "getMateData" is true.
    @objc dynamic var isNativeToken = false // TODO: AppChain ERC20 should not be marked as native token.

    var tokenBalance = 0.0  // TODO: Should persist balance, or store them globally.
    var currencyAmount = "0"

    override class func primaryKey() -> String? {
        return "identifier"
    }

    override static func ignoredProperties() -> [String] {
        return ["tokenBalance", "currencyAmount"]
    }

    struct Logo: Decodable {
        var src: String?
    }
    var logo: Logo?

    var type: TokenType {
        if isNativeToken {
            if chainId == NativeChainId.ethMainnetChainId {
                return .ether
            } else {
                if address != "" {
                    return .appChainErc20
                } else {
                    return .appChain
                }
            }
        } else {
            return .erc20
        }
    }
    var gasSymbol: String {
        switch type {
        case .ether, .erc20:
            return "ETH"
        case .appChain, .appChainErc20:
            return self.symbol
        }
    }

    var isEthereum: Bool {
        return type == .ether || type == .erc20
    }

    enum CodingKeys: String, CodingKey {
        case name
        case address
        case decimals
        case symbol
        case logo
    }
}

extension TokenModel {
    public static func == (lhs: TokenModel, rhs: TokenModel) -> Bool {
        return lhs.chainId == rhs.chainId && lhs.symbol == rhs.symbol && lhs.name == rhs.name
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? TokenModel else { return false }
        return object.address == address
    }
}
