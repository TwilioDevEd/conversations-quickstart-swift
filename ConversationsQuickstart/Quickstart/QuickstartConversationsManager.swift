//
//  QuickstartConversationsManager.swift
//  ConversationsQuickstart
//
//  Created by Jeffrey Linwood on 9/12/20.
//  Copyright © 2020 Twilio, Inc. All rights reserved.
//

import UIKit

import TwilioConversationsClient

/*
 * Delegate - usually implemented on the parent view controller. Send updates
 * that would require a user interface refresh
 */
protocol QuickstartConversationsManagerDelegate: AnyObject {
    func reloadMessages()
    func receivedNewMessage()
    func displayStatusMessage(_ statusMessage:String)
    func displayErrorMessage(_ errorMessage:String)
}

class QuickstartConversationsManager: NSObject, TwilioConversationsClientDelegate {

    // the unique name of the conversation you create
    private let uniqueConversationName = "general"

    // For the quickstart, this will be the view controller
    weak var delegate: QuickstartConversationsManagerDelegate?

    // MARK: Conversations variables
    private var client: TwilioConversationsClient?
    private var conversation: TCHConversation?
    private(set) var messages: [TCHMessage] = []
    private var identity: String?
    
    func conversationsClient(_ client: TwilioConversationsClient, synchronizationStatusUpdated status: TCHClientSynchronizationStatus) {
        guard status == .completed else {
            return
        }
        checkConversationCreation { (_, conversation) in
           if let conversation = conversation {
               self.joinConversation(conversation)
           } else {
               self.createConversation { (success, conversation) in
                   if success, let conversation = conversation {
                       self.joinConversation(conversation)
                   }
               }
           }
        }
    }


    // Called whenever a conversation we've joined receives a new message
    func conversationsClient(_ client: TwilioConversationsClient, conversation: TCHConversation,
                    messageAdded message: TCHMessage) {
        messages.append(message)

        // Changes to the delegate should occur on the UI thread
        DispatchQueue.main.async {
            if let delegate = self.delegate {
                delegate.reloadMessages()
                delegate.receivedNewMessage()
            }
        }
    }
    
    func conversationsClientTokenWillExpire(_ client: TwilioConversationsClient) {
        print("Access token will expire.")
        refreshAccessToken()
    }
    
    func conversationsClientTokenExpired(_ client: TwilioConversationsClient) {
        print("Access token expired.")
        refreshAccessToken()
    }
    
    private func refreshAccessToken() {
        guard let identity = identity else {
            return
        }
        let urlString = "\(TOKEN_URL)?identity=\(identity)"

        TokenUtils.retrieveToken(url: urlString) { (token, _, error) in
            guard let token = token else {
               print("Error retrieving token: \(error.debugDescription)")
               return
           }
            self.client?.updateToken(token, completion: { (result) in
                if (result.isSuccessful) {
                    print("Access token refreshed")
                } else {
                    print("Unable to refresh access token")
                }
            })
        }
    }

    func sendMessage(_ messageText: String,
                     completion: @escaping (TCHResult, TCHMessage?) -> Void) {
        
        let messageOptions = TCHMessageOptions().withBody(messageText)
        conversation?.sendMessage(with: messageOptions, completion: { (result, message) in
            completion(result, message)
        })
    
    }

    func loginFromServer(_ identity: String, completion: @escaping (Bool) -> Void) {
        // Fetch Access Token from the server and initialize the Conversations Client
        let urlString = "\(TOKEN_URL)?identity=\(identity)"
        self.identity = identity

        TokenUtils.retrieveToken(url: urlString) { (token, _, error) in
            guard let token = token else {
                print("Error retrieving token: \(error.debugDescription)")
                completion(false)
                return
            }
            // Set up Twilio Conversations client
            TwilioConversationsClient.conversationsClient(withToken: token,
                                                          properties: nil,
                                                          delegate: self) { (result, client) in
                                                            self.client = client
                                                            completion(result.isSuccessful)
            }
        }
    }
    
    func loginWithAccessToken(_ token: String) {
        // Set up Twilio Conversations client
        TwilioConversationsClient.conversationsClient(withToken: token,
         properties: nil,
         delegate: self) { (result, client) in
           self.client = client
        }
    }

    func shutdown() {
        if let client = client {
            client.delegate = nil
            client.shutdown()
            self.client = nil
        }
    }

    private func createConversation(_ completion: @escaping (Bool, TCHConversation?) -> Void) {
        guard let client = client else {
            return
        }
        // Create the conversation if it hasn't been created yet
        let options: [String: Any] = [
            TCHConversationOptionUniqueName: uniqueConversationName
            ]
        client.createConversation(options: options) { (result, conversation) in
            if result.isSuccessful {
                print("Conversation created.")
            } else {
                print(result.error?.localizedDescription ?? "")
                print("Conversation NOT created.")
            }
            completion(result.isSuccessful, conversation)
        }
    }

    private func checkConversationCreation(_ completion: @escaping(TCHResult?, TCHConversation?) -> Void) {
        guard let client = client else {
            return
        }
        client.conversation(withSidOrUniqueName: uniqueConversationName) { (result, conversation) in
            completion(result, conversation)
        }
        //let myConversations = client.myConversations()
        //completion(TCHResult(), client.myConversations()?.first)
    }

    private func joinConversation(_ conversation: TCHConversation) {
        self.conversation = conversation
        if conversation.status == .joined {
            print("Current user already exists in conversation")
            self.loadPreviousMessages(conversation)
        } else {
            conversation.join(completion: { result in
                print("Result of conversation join: \(result.resultText ?? "No Result")")
                if result.isSuccessful {
                    self.loadPreviousMessages(conversation)
                }
            })
        }
    }
    
    private func loadPreviousMessages(_ conversation: TCHConversation) {
        conversation.getLastMessages(withCount: 100) { (result, messages) in
            if let messages = messages {
                self.messages = messages
                self.delegate?.reloadMessages()
            }
        }
    }
}
