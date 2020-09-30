//
//  ConversationsViewController.swift
//  ConversationsQuickstart
//
//  Created by Jeffrey Linwood on 9/12/20.
//  Copyright © 2020 Twilio, Inc. All rights reserved.
//

import UIKit

class ConversationsViewController: UIViewController {

    // Important - this identity would be assigned by your app, for
    // instance after a user logs in
    var identity = "USER_IDENTITY"

    // Convenience class to manage interactions with Twilio Conversations
    var conversationsManager = QuickstartConversationsManager()

    // MARK: UI controls
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        conversationsManager.delegate = self

        // Listen for keyboard events and animate text field as necessary
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardDidShow),
                                               name: UIResponder.keyboardDidShowNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)

        // Set up UI controls
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 66.0
        self.tableView.separatorStyle = .none
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //loginFromServer()
        loginWithTestAccessToken()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        conversationsManager.shutdown()
    }

    // MARK: Login

    func loginFromServer() {
        conversationsManager.loginFromServer(self.identity) { (success) in
            DispatchQueue.main.async {
                if success {
                    self.navigationItem.prompt = "Logged in as \"\(self.identity)\""
                } else {
                    self.navigationItem.prompt = "Unable to login"
                    let msg = "Unable to login - check the token URL in ConversationsConstants.swift"
                    self.displayErrorMessage(msg)
                }
            }
        }
    }
    
    func loginWithTestAccessToken() {
        conversationsManager.loginWithAccessToken(TEST_ACCESS_TOKEN)
        self.navigationItem.prompt = "Logged in"
    }

    // MARK: Keyboard Dodging Logic

    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardRect = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey]
            as? NSValue)?.cgRectValue {
            UIView.animate(withDuration: 0.1, animations: { () -> Void in
                self.bottomConstraint.constant = keyboardRect.height + 10
                self.view.layoutIfNeeded()
            })
        }
    }

    @objc func keyboardDidShow(notification: NSNotification) {
        scrollToBottomMessage()
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        UIView.animate(withDuration: 0.1, animations: { () -> Void in
            self.bottomConstraint.constant = 20
            self.view.layoutIfNeeded()
        })
    }

    // MARK: UI Logic

    // Dismiss keyboard if container view is tapped
    @IBAction func viewTapped(_ sender: Any) {
        self.textField.resignFirstResponder()
    }

    private func scrollToBottomMessage() {
        if conversationsManager.messages.count == 0 {
            return
        }
        let bottomMessageIndex = IndexPath(row: conversationsManager.messages.count - 1,
                                           section: 0)
        tableView.scrollToRow(at: bottomMessageIndex, at: .bottom, animated: true)
    }

}

// MARK: UITextField Delegate
extension ConversationsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        conversationsManager.sendMessage(textField.text!, completion: { (result, _) in
            if result.isSuccessful {
                textField.text = ""
                textField.resignFirstResponder()
            } else {
                self.displayErrorMessage("Unable to send message")
            }
        })
        return true
    }
}

// MARK: UITableViewDataSource Delegate
extension ConversationsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    // Return number of rows in the table
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return conversationsManager.messages.count
    }

    // Create table view rows
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
        -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell",
                                                     for: indexPath)
            let message = conversationsManager.messages[indexPath.row]

            // Set table cell values
            cell.detailTextLabel?.text = message.author
            cell.textLabel?.text = message.body
            cell.selectionStyle = .none
            return cell
    }
}

// MARK: QuickstartConversationsManagerDelegate
extension ConversationsViewController: QuickstartConversationsManagerDelegate {
    func displayStatusMessage(_ statusMessage: String) {
        self.navigationItem.prompt = statusMessage
    }
    
    
    func displayErrorMessage(_ errorMessage: String) {
        let alertController = UIAlertController(title: "Error",
                                                message: errorMessage,
                                                preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    
    func reloadMessages() {
        self.tableView.reloadData()
    }

    // Scroll to bottom of table view for messages
    func receivedNewMessage() {
        scrollToBottomMessage()
    }
}
