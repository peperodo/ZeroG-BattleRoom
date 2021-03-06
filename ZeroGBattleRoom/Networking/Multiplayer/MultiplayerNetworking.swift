//
//  MultiplayerNetworking.swift
//  ZeroG BattleRoom
//
//  Created by Rudy Gomez on 3/28/20.
//  Copyright © 2020 JRudy Gaming. All rights reserved.
//

import Foundation
import SpriteKit
import GameKit


extension Notification.Name {
  static let startMatchmaking = Notification.Name("start_match_making")
}


class MultiplayerNetworking {
  
  enum DetailsKeys: String, CaseIterable {
    case player = "PlayerKey"
    case randomNumber = "RandomNumberKey"
    
    static var playerKey: String {
      return DetailsKeys.player.rawValue
    }
    
    static var randomNumberKey: String {
      return DetailsKeys.randomNumber.rawValue
    }
  }
  
  enum GameState: Int {
    case waitingForMatch
    case waitingForRandomNumber
    case waitingForStart
    case active
    case done
  }
  
  var gameState: GameState = .waitingForMatch
  
  var ourRandomNumber = Double.random(in: 0.0...1000.0)
  private var allRandomNumbersReceived: Bool {
    guard let match = GameKitHelper.shared.match else { return false }
    
    return self.orderOfPlayers.count == match.players.count + 1
  }
  
  private lazy var baseOrder: [[String: Any]] = {
    return [[
      DetailsKeys.playerKey: GKLocalPlayer.local,
      DetailsKeys.randomNumberKey: self.ourRandomNumber]]
  }()
  var orderOfPlayers = [[String: Any]]()
  var recievedAllRandomNumbers = false
  var isPlayer1 = false
  
  var indicesForPlayers: (local: Int, remote: Int ) {
    return self.isPlayer1 ? (local: 0, remote: 1) :  (local: 1, remote: 0)
  }
  
  var playerAliases: [String] {
    var aliases = [String]()
    for playerDetails in self.orderOfPlayers {
      if let player = playerDetails[DetailsKeys.playerKey] as? GKPlayer {
        aliases.append(player.alias)
      }
    }
    
    return aliases
  }
  
  var delegate: MultiplayerNetworkingProtocol?
  
  init() {
    self.resetPlayerOrder()
  }
  
  func resetPlayerOrder() {
    self.orderOfPlayers = baseOrder
  }
  
  func sendData(_ data: Data, mode: GKMatch.SendDataMode = .reliable) {
    guard let match = GameKitHelper.shared.match else { return }
    
    do {
      try match.send(data, to: match.players, dataMode: mode)
    } catch {
      print("Error sending data: \(error.localizedDescription)")
      self.matchEnded()
    }
  }
}

extension MultiplayerNetworking {
  func sendMove(start pos: CGPoint, rotation: CGFloat, velocity: CGVector, angularVelocity: CGFloat, wasLaunch: Bool) {
    let playerElement = MessageSnapshotElement(position: pos,
                                               rotation: rotation,
                                               velocity: velocity,
                                               angularVelocity: angularVelocity)
    let message = UnifiedMessage(type: .move, boolValue: wasLaunch, elements: [[playerElement]])
    self.sendData(Data.archiveJSON(object: message))
  }
  
//  func sendImpacted(senderIndex: Int) {
//    let message = UnifiedMessage(type: .impacted, senderIndex: senderIndex)
////    self.sendData(Data.archiveJSON(object: message))
//  }
//  
//  func sendWall(index: Int, isOccupied: Bool) {
//    let message = UnifiedMessage(type: .wallHit,
//                                 boolValue: isOccupied,
//                                 resourceIndex: index)
////    self.sendData(Data.archiveJSON(object: message))
//  }
//  
//  func sendGrabbedResource(index: Int, playerIndex: Int, senderIndex: Int) {
//    let message = UnifiedMessage(type: .grabResource, resourceIndex: index,
//                                 playerIndex: playerIndex,
//                                 senderIndex: senderIndex)
////    self.sendData(Data.archiveJSON(object: message))
//  }
//  
//  func sendAssignResource(index: Int, playerIndex: Int) {
//    let message = UnifiedMessage(type: .assignResource, resourceIndex: index,
//                                 playerIndex: playerIndex)
////    self.sendData(Data.archiveJSON(object: message))
//  }
//  
//  func sendResourceMoveAt(index: Int, start pos: CGPoint, direction: CGVector) {
////    let resourceElement = MessageSnapshotElement(position: pos, rotation: .zero, velocity: direction)
////    let message = UnifiedMessage(type: .moveResource, resourceIndex: index, elements: [[resourceElement]])
////    self.sendData(Data.archiveJSON(object: message))
//  }
  
  func sendSnapshot(_ elements: [SnapshotElementGroup]) {
    let message = UnifiedMessage(type: .snapshot, elements: elements)
    self.sendData(Data.archiveJSON(object: message), mode: .unreliable)
  }
  
  func sendRandomNumber() {
    let message = UnifiedMessage(type: .randomeNumber, randomNumber: self.ourRandomNumber)
    self.sendData(Data.archiveJSON(object: message))
  }
  
  func sendGameBegin() {
    let message = UnifiedMessage(type: .gameBegin)
    self.sendData(Data.archiveJSON(object: message))
  }
  
  func sendGameEnd(player1Won: Bool) {
    let message = UnifiedMessage(type: .gameOver, boolValue: player1Won)
    self.sendData(Data.archiveJSON(object: message))
  }
}

extension MultiplayerNetworking {
  func processReceivedRandomNumber(randomNumberDetails: [String: Any]) {
    guard randomNumberDetails.count > 0 else {
      print("Error: Expected random details missing.")
      return
    }
    
    let firstIndex = self.orderOfPlayers.firstIndex(where: { details in
      let detailsPlayer = details[DetailsKeys.playerKey] as! GKPlayer
      let player = randomNumberDetails[DetailsKeys.playerKey] as! GKPlayer

      return detailsPlayer == player
    })
    
    if let index = firstIndex {
      let randomNumber = randomNumberDetails[DetailsKeys.randomNumberKey]
      self.orderOfPlayers[index][DetailsKeys.randomNumberKey] = randomNumber
    } else {
      self.orderOfPlayers.append(randomNumberDetails)
    }
    
    self.orderOfPlayers.sort { first, second in
      let firstNumber = first[DetailsKeys.randomNumberKey] as! Double
      let secondNumber = second[DetailsKeys.randomNumberKey] as! Double
    
      return firstNumber > secondNumber
    }
    
    if self.allRandomNumbersReceived {
      self.recievedAllRandomNumbers = true
    }
  }
  
  private func indexForLocal(player: GKPlayer) -> Int {
    return self.orderOfPlayers.firstIndex { details -> Bool in
      let detailsPlayer = details[DetailsKeys.playerKey] as! GKPlayer
      
      return player == detailsPlayer
    }!
  }
  
  func processPlayerAliases() {
    if self.allRandomNumbersReceived {
      if playerAliases.count > 0 {
        self.delegate?.setPlayerAliases(playerAliases: self.playerAliases)
      }
    }
  }
}
