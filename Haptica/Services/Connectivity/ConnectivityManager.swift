//
//  ConnectivityManager.swift
//  MultipeerChat
//
//  Created by Nozhan Amiri on 10/3/24.
//

import Foundation
import MultipeerConnectivity

class ConnectivityManager: NSObject, ObservableObject {
    typealias PeerDataHandler = (Data, MCPeerID) -> Void
    
    @Published var peerID: MCPeerID? = nil
    @Published var connectedPeers: [MCPeerID] = []
    @Published var nearbyPeers: [NearbyPeer] = []
    @Published var selectedPeer: NearbyPeer?
    @Published var peerDidChangeState: PeerEvent? = nil
    @Published var invitation: PeerInvitation? = nil
    @Published var hasInvitation: Bool = false
    @Published private(set) var discoverable: Bool = false
    @Published private(set) var isInitialized: Bool = false
    
    private var session: MCSession!
    private var browser: MCNearbyServiceBrowser!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var dataHandlers: [PeerDataHandler] = []
    private var isStreaming = false
    private var outputStream: OutputStream?
    
    var chatName: String? {
        advertiser.discoveryInfo?["chatName"]
    }
    
    var displayName: String? {
        peerID?.displayName
    }
    
    var isConnected: Bool {
        !connectedPeers.isEmpty
    }
    
    deinit {
        terminateSessionAndDiscovery()
    }
    
    func startBrowsing() {
        self.nearbyPeers = []
        self.peerDidChangeState = nil
        browser.startBrowsingForPeers()
        print("Started browsing for peers.")
    }
    
    func stopBrowsing() {
        self.nearbyPeers = []
        self.peerDidChangeState = nil
        browser.stopBrowsingForPeers()
        print("Stopped browsing for peers.")
    }
    
    func startAdvertising(withChatName chatName: String? = nil) {
        self.invitation = nil
        self.hasInvitation = false
        self.peerDidChangeState = nil
        if let chatName {
            let advertiser = NearbyPeer(peerID: peerID!, discoveryInfo: .init(device: UIDevice.current.name, chatName: chatName))
                .makeAdvertiser(serviceType: "haptica-mc")
            advertiser.delegate = self
            self.advertiser = advertiser
        }
        advertiser.startAdvertisingPeer()
        self.discoverable = true
        print("Started advertising for peers.")
    }
    
    func stopAdvertising() {
        self.invitation = nil
        self.hasInvitation = false
        self.peerDidChangeState = nil
        advertiser.stopAdvertisingPeer()
        self.discoverable = false
        print("Stopped advertising for peers.")
    }
    
    func disconnectSession() {
        self.session.disconnect()
        self.connectedPeers = []
    }
    
    func initializeSession(withDisplayName name: String) {
        let peerID = MCPeerID(displayName: name)
        let session = MCSession(peer: peerID)
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: "haptica-mc")
        let myAdvertisingPeer = NearbyPeer(peerID: peerID, discoveryInfo: .init(device: UIDevice.current.name, chatName: ""))
        let advertiser = myAdvertisingPeer.makeAdvertiser(serviceType: "haptica-mc")
        
        session.delegate = self
        browser.delegate = self
        advertiser.delegate = self
        
        self.session = session
        self.peerID = peerID
        self.browser = browser
        self.advertiser = advertiser
        self.isInitialized = true
    }
    
    func initializeSessionIfNonexistent(withDisplayName displayName: String) {
        guard session == nil else { return }
        initializeSession(withDisplayName: displayName)
    }
    
    func terminateSessionAndDiscovery() {
        stopAdvertising()
        stopBrowsing()
        self.session.disconnect()
        self.discoverable = false
        self.connectedPeers = []
        self.nearbyPeers = []
        self.invitation = nil
        self.hasInvitation = false
        self.dataHandlers = []
        self.peerDidChangeState = nil
        self.advertiser = nil
        self.browser = nil
        self.session = nil
        self.peerID = nil
    }
    
    func on<Received>(_ decodable: Received.Type, perform completion: @escaping (Received, MCPeerID) -> Void) where Received: Decodable {
        let dataHandler: PeerDataHandler = { data, peerID in
            if let decoded = try? JSONDecoder().decode(decodable, from: data) {
                completion(decoded, peerID)
            }
        }
        self.dataHandlers.append(dataHandler)
    }
    
    func send<Transmitted>(_ encodable: Transmitted) where Transmitted: Encodable {
        guard let session,
              let encoded = try? JSONEncoder().encode(encodable) else { return }
        do {
            try session.send(encoded, toPeers: connectedPeers, with: .reliable)
        } catch {
            print("Failed to send data to \(connectedPeers.count) peers: \(encoded.count) Bytes")
        }
    }
    
    func openStream(withPeerID peerID: MCPeerID) throws {
        guard connectedPeers.contains(peerID) else { return }
        outputStream?.close()
        outputStream = try session.startStream(withName: "hapica-mc", toPeer: peerID)
    }
    
    func closeStream() {
        outputStream?.close()
        outputStream = nil
    }
    
    func stream<Transmitted>(_ encodable: Transmitted) where Transmitted: Encodable {
        guard let session,
              isStreaming,
              let outputStream,
              let data = try? JSONEncoder().encode(encodable) else { return }
        let bufferSize = 1024
        let bytesWritten = data.withUnsafeBytes { buffer in
            outputStream.write(buffer, maxLength: bufferSize)
        }
        
        print("Bytes written: \(bytesWritten)")
    }
    
    func resetSession(andInitializeWithDisplayName displayName: String) {
        terminateSessionAndDiscovery()
        initializeSession(withDisplayName: displayName)
    }
    
    func invitePeer(_ peerID: MCPeerID) {
        guard let session else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }
    
    func acceptInvitation(_ invitation: PeerInvitation) {
        guard let session else { return }
        invitation.handler(true, session)
    }
    
    func declineInvitation(_ invitation: PeerInvitation) {
        guard let session else { return }
        invitation.handler(false, session)
    }
}

extension ConnectivityManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            connectedPeers = session.connectedPeers
            nearbyPeers = nearbyPeers.filter { [weak self] peer in
                guard let self else { return false }
                return connectedPeers.allSatisfy { $0 != peer.peerID }
            }
            peerDidChangeState = PeerEvent(peerID: peerID, state: state)
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        for dataHandler in self.dataHandlers {
            dataHandler(data, peerID)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        stream.open()
        defer {
            stream.close()
        }
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }
        var data = Data()
        while stream.hasBytesAvailable {
            stream.read(buffer, maxLength: bufferSize)
            data.append(buffer, count: bufferSize)
        }
        for dataHandler in self.dataHandlers {
            dataHandler(data, peerID)
        }
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("Resources not implemented")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print("Resources not implemented")
    }
}

extension ConnectivityManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        let peer = NearbyPeer(peerID: peerID, discoveryInfo: info)
        print("Found peer: \(peer.peerID.displayName) - \(String(describing: peer.discoveryInfo?.device))")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if connectedPeers.allSatisfy({ peer.peerID != $0 }) {
                nearbyPeers = nearbyPeers + [peer]
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost peer: \(peerID.displayName)")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            nearbyPeers = nearbyPeers.filter { peer in
                peer.peerID != peerID
            }
        }
    }
}

extension ConnectivityManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        self.invitation = PeerInvitation(peerID: peerID, context: context, handler: invitationHandler)
        self.hasInvitation = true
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to start advertiser: \(error.localizedDescription)")
    }
}
