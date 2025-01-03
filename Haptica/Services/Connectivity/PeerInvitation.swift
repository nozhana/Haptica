//
//  PeerInvitation.swift
//  MultipeerChat
//
//  Created by Nozhan Amiri on 10/3/24.
//

import Foundation
import MultipeerConnectivity

struct PeerInvitation: Identifiable {
    typealias Handler = (Bool, MCSession?) -> Void
    
    let peerID: MCPeerID
    let context: Context?
    let handler: Handler
    
    var id: MCPeerID { peerID }
    
    struct Context: Codable {
        let message: String?
        let device: String
        
        var data: Data? {
            try? JSONEncoder().encode(self)
        }
    }
    
    init(peerID: MCPeerID, context: Context?, handler: @escaping Handler) {
        self.peerID = peerID
        self.context = context
        self.handler = handler
    }
    
    init(peerID: MCPeerID, context data: Data?, handler: @escaping Handler) {
        let context: Context?
        if let data {
            context = try? JSONDecoder().decode(Context.self, from: data)
        } else {
            context = nil
        }
        self.peerID = peerID
        self.context = context
        self.handler = handler
    }
}
