//
//  SendTransactionViewController.swift
//  Neuron
//
//  Created by 晨风 on 2018/10/30.
//  Copyright © 2018 Cryptape. All rights reserved.
//

import UIKit
import BLTNBoard
import BigInt
import AppChain
import Web3swift
import EthereumAddress

class SendTransactionViewController: UITableViewController {
    @IBOutlet private weak var walletIconView: UIImageView!
    @IBOutlet private weak var walletNameLabel: UILabel!
    @IBOutlet private weak var walletAddressLabel: UILabel!
    @IBOutlet private weak var tokenBalanceButton: UIButton!
    @IBOutlet private weak var amountTextField: UITextField!
    @IBOutlet private weak var gasCostLabel: UILabel!
    @IBOutlet private weak var addressTextField: UITextField!

    private var paramBuilder: TransactionParamBuilder!
    private var observers = [NSKeyValueObservation]()

    private lazy var summaryPageItem: TxSummaryPageItem = {
        return TxSummaryPageItem.create()
    }()
    private lazy var bulletinManager: BLTNItemManager = {
        let passwordPageItem = createPasswordPageItem()
        summaryPageItem.next = passwordPageItem
        summaryPageItem.actionHandler = { item in
            item.manager?.displayNextItem()
        }

        return BLTNItemManager(rootItem: summaryPageItem)
    }()

    var token: TokenModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        paramBuilder = TransactionParamBuilder(token: token)
        observers.append(paramBuilder.observe(\.txFeeNatural, options: [.initial]) { (_, _) in
            self.updateGasCost()
        })
        paramBuilder.from = WalletRealmTool.getCurrentAppModel().currentWallet!.address

        setupUI()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "TransactionGasPriceViewController" {
            let controller = segue.destination as! TransactionGasPriceViewController
            controller.param = paramBuilder
        }
    }

    @IBAction func next(_ sender: Any) {
        view.endEditing(true)

        let amount = Double(amountTextField.text!) ?? 0.0
        paramBuilder.value = amount.toAmount(token.decimals)
        paramBuilder.to = addressTextField.text!

        if isEffectiveTransferInfo {
            summaryPageItem.update(paramBuilder)
            bulletinManager.showBulletin(above: self)
        }
    }

    @IBAction func scanQRCode() {
        UIApplication.shared.keyWindow?.endEditing(true)
        let qrCodeViewController = QRCodeViewController()
        qrCodeViewController.delegate = self
        navigationController?.pushViewController(qrCodeViewController, animated: true)
    }

    @IBAction func transactionAvailableBalance() {
        // TODO: FIXME: erc20 token requires ETH balance for tx fee
        let amount = Double(token.tokenBalance)! - paramBuilder.txFeeNatural
        amountTextField.text = "\(amount)"
        paramBuilder.value = amount.toAmount(token.decimals)
        guard paramBuilder.hasSufficientBalance else {
            Toast.showToast(text: "请确保账户剩余\(token.gasSymbol)高于矿工费用，以便顺利完成转账～")
            return
        }
    }

    // MARK: - UI
    func setupUI() {
        let wallet = WalletRealmTool.getCurrentAppModel().currentWallet!
        title = "\(token.symbol)转账"
        walletIconView.image = UIImage(data: wallet.iconData)
        walletNameLabel.text = wallet.name
        walletAddressLabel.text = wallet.address
        tokenBalanceButton.setTitle("\(token.tokenBalance)\(token.symbol)", for: .normal)
        updateGasCost()
    }

    private func updateGasCost() {
        gasCostLabel.text = "\(paramBuilder.txFeeNatural.decimal)\(paramBuilder.nativeCoinSymbol)"
    }

    private func createPasswordPageItem() -> PasswordPageItem {
        let passwordPageItem = PasswordPageItem.create()

        passwordPageItem.actionHandler = { [weak self] item in
            item.manager?.displayActivityIndicator()
            guard let self = self else {
                return
            }
            self.sendTransaction(password: passwordPageItem.passwordField.text!)
        }

        return passwordPageItem
    }
}

// MARK: - Send Transaction

private extension SendTransactionViewController {
    func sendTransaction(password: String) {
        DispatchQueue.global().async {
            do {
                // TODO: send tx for real
                Thread.sleep(forTimeInterval: 1)
                throw SendTransactionError.invalidPassword

                DispatchQueue.main.async {
                    let successPageItem = SuccessPageItem.create(title: "交易已发送")
                    successPageItem.actionHandler = { item in
                        item.manager?.dismissBulletin(animated: true)
                    }
                    self.bulletinManager.push(item: successPageItem)
                }
            } catch let error {
                DispatchQueue.main.async {
                    self.bulletinManager.hideActivityIndicator()
                    /// HACKHACK: Possible a bug of BulletinBoard, but after hiding activity indicator
                    /// the previous page item's views stop responding to update. To get around that
                    /// create a new item. Note this would leave more than one password item in the stack.
                    let passwordPageItem = self.createPasswordPageItem()
                    self.bulletinManager.push(item: passwordPageItem)
                    passwordPageItem.errorMessage = error.localizedDescription
                }
            }
        }
    }

    var isEffectiveTransferInfo: Bool {
        guard Address.isValid(paramBuilder.to) && paramBuilder.to != "0x" else {
            Toast.showToast(text: "您的地址错误，请重新输入")
            return false
        }

        // TODO: FIXME: erc20 requires eth balance as tx fee
        if paramBuilder.hasSufficientBalance {
            return true
        }

        if paramBuilder.tokenBalance <= BigUInt(0) {
            Toast.showToast(text: "请确保账户剩余\(token.gasSymbol)高于矿工费用，以便顺利完成转账～")
            return false
        }
        let alert = UIAlertController(title: "您输入的金额超过您的余额，是否全部转出？", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确认", style: .default, handler: { (_) in
            self.transactionAvailableBalance()
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .destructive, handler: { (_) in
            self.amountTextField.text = ""
        }))
        present(alert, animated: true, completion: nil)
        return false
    }
}

extension SendTransactionViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension SendTransactionViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == amountTextField {
            let character: String
            if (textField.text?.contains("."))! {
                character = "0123456789"
            } else {
                character = "0123456789."
            }
            guard CharacterSet(charactersIn: character).isSuperset(of: CharacterSet(charactersIn: string)) else {
                return false
            }
            return true
        }
        return true
    }
}

extension SendTransactionViewController: QRCodeViewControllerDelegate {
    func didBackQRCodeMessage(codeResult: String) {
        addressTextField.text = codeResult
    }
}
