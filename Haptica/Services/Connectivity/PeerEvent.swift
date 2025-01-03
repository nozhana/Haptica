//
//  PeerEvent.swift
//  MultipeerChat
//
//  Created by Nozhan Amiri on 10/3/24.
//

import Foundation
import MultipeerConnectivity

struct PeerEvent: Equatable {
    let peerID: MCPeerID
    let state: MCSessionState
    
    static func connected(_ peerID: MCPeerID) -> PeerEvent {
        PeerEvent(peerID: peerID, state: .connected)
    }
    
    static func connecting(_ peerID: MCPeerID) -> PeerEvent {
        PeerEvent(peerID: peerID, state: .connecting)
    }
    
    static func notConnected(_ peerID: MCPeerID) -> PeerEvent {
        PeerEvent(peerID: peerID, state: .notConnected)
    }
}
