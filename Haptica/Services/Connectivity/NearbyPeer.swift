//
//  NearbyPeer.swift
//  MultipeerChat
//
//  Created by Nozhan Amiri on 10/3/24.
//

import Foundation
import MultipeerConnectivity

struct NearbyPeer: Identifiable {
    let peerID: MCPeerID
    let discoveryInfo: DiscoveryInfo?
    
    var id: MCPeerID { peerID }
    
    struct DiscoveryInfo: RawRepresentable {
        let device: String
        let chatName: String
        var rawValue: [String: String] {
            ["device": device,
            "chatName": chatName]
        }
        
        init(device: String, chatName: String) {
            self.device = device
            self.chatName = chatName
        }
        
        init?(rawValue: [String : String]) {
            guard let device = rawValue["device"],
                  let chatName = rawValue["chatName"] else { return nil }
            self.device = device
            self.chatName = chatName
        }
    }
    
    init(peerID: MCPeerID, discoveryInfo: DiscoveryInfo?) {
        self.peerID = peerID
        self.discoveryInfo = discoveryInfo
    }
    
    init(peerID: MCPeerID, discoveryInfo dict: [String: String]?) {
        if let dict {
            let info = DiscoveryInfo(rawValue: dict)
            self.discoveryInfo = info
        } else {
            self.discoveryInfo = nil
        }
        self.peerID = peerID
    }
    
    func makeAdvertiser(serviceType: String) -> MCNearbyServiceAdvertiser {
        MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: discoveryInfo?.rawValue, serviceType: serviceType)
    }
}
