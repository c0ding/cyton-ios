//
//  ERC20TokenService.swift
//  Neuron
//
//  Created by XiaoLu on 2018/7/4.
//  Copyright © 2018年 cryptape. All rights reserved.
//

import Foundation
import Web3swift
import EthereumAddress
import struct BigInt.BigUInt

struct ERC20TokenService {
    /// search ETC20Token data for contractaddress
    ///
    /// - Parameters:
    ///   - contractAddress: contractAddress
    ///   - walletAddress: walletAddress
    ///   - completion: result
    static func addERC20TokenToApp(contractAddress: String, walletAddress: String, completion:@escaping (EthServiceResult<TokenModel>) -> Void) {
        var ethAddress: EthereumAddress?
        let cAddress = contractAddress.addHexPrefix()
        ethAddress = EthereumAddress(cAddress)

        guard ethAddress != nil else {
            completion(EthServiceResult.error(CustomTokenError.undefinedError))
            return
        }

        let tokenModel = TokenModel()
        DispatchQueue.global(qos: .userInitiated).async {
            let disGroup = DispatchGroup()

            disGroup.enter()
            CustomERC20TokenService.name(walletAddress: walletAddress, token: cAddress, completion: { (result) in
                switch result {
                case .success(let name):
                    tokenModel.name = name
                case .error:
                    break
                }
                disGroup.leave()
            })

            disGroup.enter()
            CustomERC20TokenService.symbol(walletAddress: walletAddress, token: cAddress, completion: { (result) in
                switch result {
                case .success(let symbol):
                    tokenModel.symbol = symbol
                case .error:
                    break
                }
                disGroup.leave()
            })

            disGroup.enter()
            CustomERC20TokenService.decimals(walletAddress: walletAddress, token: cAddress, completion: { (result) in
                switch result {
                case .success(let decimals):
                    tokenModel.decimals = Int(decimals)
                case .error:
                    break
                }
                disGroup.leave()
            })

            disGroup.notify(queue: .main) {
                guard !tokenModel.name.isEmpty, !tokenModel.symbol.isEmpty else {
                    completion(EthServiceResult.error(CustomTokenError.undefinedError))
                    return
                }
                completion(EthServiceResult.success(tokenModel))
            }
        }
    }
}
