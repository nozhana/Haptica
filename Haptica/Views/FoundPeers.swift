//
//  FoundPeers.swift
//  Haptica
//
//  Created by Nozhan Amiri on 1/2/25.
//

import ToastKit
import SwiftUI
import MultipeerConnectivity

struct FoundPeers: View {
    @EnvironmentObject private var connectivity: ConnectivityManager
    @Environment(\.dismiss) private var dismiss
    @State private var showDisconnectAlert = false
    @State private var pendingInvitation: MCPeerID?
    @State private var showRenameAlert = false
    @State private var connectingPeers: Set<MCPeerID> = []
    @State private var myName = Defaults[.myName] ?? "Haptica User"
    
    private func listRow(for peer: MCPeerID) -> some View {
        Button(peer.displayName, systemImage: "dot.circle") {
            if connectivity.isConnected {
                pendingInvitation = peer
                showDisconnectAlert = true
                return
            }
            connectivity.invitePeer(peer)
            connectingPeers.insert(peer)
        } // Button
        .blur(radius: connectingPeers.contains(peer) ? 16 : 0)
        .overlay {
            if connectingPeers.contains(peer) {
                ProgressView()
                    .frame(width: 44, height: 44)
            }
        } // overlay
        .animation(.easeInOut(duration: 1), value: connectingPeers)
    }
    
    var body: some View {
        NavigationStack {
            List(connectivity.nearbyPeers) { peer in
                listRow(for: peer.peerID)
                    .withUnwrappedOptional(connectivity.peerDidChangeState) { content, peerState in
                        content
                            .onChange(of: peerState) { newValue in
                                switch newValue.state {
                                case .connecting:
                                    connectingPeers.insert(newValue.peerID)
                                default:
                                    connectingPeers.remove(newValue.peerID)
                                }
                            }
                    }
            } // List
            .toast(isPresented: $showDisconnectAlert, titleKey: "You'll have to disconnect from \(connectivity.connectedPeers.first?.displayName ?? "your current session") before inviting \(pendingInvitation?.displayName ?? "another peer").", systemImage: "link") {
                Group {
                    Button("Cancel", role: .cancel) {
                        pendingInvitation = nil
                        withAnimation {
                            showDisconnectAlert = false
                        }
                    }
                    
                    Button("Disconnect", role: .destructive) {
                        connectivity.disconnectSession()
                        if let pendingInvitation {
                            connectivity.invitePeer(pendingInvitation)
                            self.pendingInvitation = nil
                        }
                        withAnimation {
                            showDisconnectAlert = false
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .toastDuration(6)
            .toast(isPresented: $connectivity.hasInvitation, titleKey: "New Invitation from \(connectivity.invitation?.peerID.displayName ?? "Unknown")", systemImage: "envelope.fill") {
                if let invitation = connectivity.invitation {
                    Group {
                        Button("Decline", role: .destructive) {
                            connectivity.declineInvitation(invitation)
                            withAnimation {
                                connectivity.hasInvitation = false
                            }
                        }
                        
                        Button("Accept") {
                            connectivity.acceptInvitation(invitation)
                            withAnimation {
                                connectivity.hasInvitation = false
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .toastPersistent()
            .alert("Change your name", isPresented: $showRenameAlert) {
                TextField("New name", text: $myName)
                Button("Cancel", role: .cancel) {}
                Button("Confirm") {
                    connectivity.terminateSessionAndDiscovery()
                    connectivity.initializeSession(withDisplayName: myName)
                    Defaults[.myName] = myName
                }
            }
            .onChange(of: connectivity.isConnected) { isConnected in
                if isConnected {
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(myName, systemImage: "pencil") {
                        showRenameAlert = true
                    }
                }
            }
            .navigationTitle("Found peers")
            .onAppear {
                if !connectivity.isInitialized {
                    connectivity.initializeSession(withDisplayName: myName)
                }
                
                connectivity.startAdvertising(withChatName: "Hello World")
                connectivity.startBrowsing()
            }
            .onDisappear {
                connectivity.stopAdvertising()
                connectivity.stopBrowsing()
            }
        } // NavigationStack
    }
}

#Preview {
    FoundPeers()
}

extension View {
    @ViewBuilder
    func withUnwrappedOptional<T>(_ optional: T?, unwrapped completion: @escaping (Self, T) -> some View) -> some View {
        if let unwrapped = optional {
            completion(self, unwrapped)
        } else {
            self
        }
    }
}
