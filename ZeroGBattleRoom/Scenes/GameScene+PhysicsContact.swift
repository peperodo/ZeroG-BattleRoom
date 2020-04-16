//
//  GameScene+PhysicsContact.swift
//  SpaceMonkies
//
//  Created by Rudy Gomez on 3/26/20.
//  Copyright © 2020 JRudy Gaming. All rights reserved.
//

import Foundation
import SpriteKit
import GameKit

extension GameScene: SKPhysicsContactDelegate {
  func didBegin(_ contact: SKPhysicsContact) {
    guard self.gameState.currentState is Playing  else { return }
    
    var firstBody: SKPhysicsBody
    var secondBody: SKPhysicsBody
    
    if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
      firstBody = contact.bodyA
      secondBody = contact.bodyB
    } else {
      firstBody = contact.bodyB
      secondBody = contact.bodyA
    }
    
    if firstBody.categoryBitMask == PhysicsCategoryMask.hero &&
      secondBody.categoryBitMask == PhysicsCategoryMask.hero {
      
      guard let firstHeroNode = firstBody.node as? SKSpriteNode,
        let secondHeroNode = secondBody.node as? SKSpriteNode else { return }
      guard let firstHero = self.entityManager.heroWith(node: firstHeroNode) as? General,
        let firstHeroHandsComponent = firstHero.component(ofType: HandsComponent.self),
        let secondHero = self.entityManager.heroWith(node: secondHeroNode) as? General,
        let secondHeroHandsComponent = secondHero.component(ofType: HandsComponent.self),
        !firstHeroHandsComponent.isImpacted && !secondHeroHandsComponent.isImpacted else { return }
      
      firstHero.impacted()
      secondHero.impacted()
      
      self.multiplayerNetworking.sendImpacted(senderIndex: 0)
      self.multiplayerNetworking.sendImpacted(senderIndex: 1)
      
      print("heros collided")
    }
    
    if firstBody.categoryBitMask == PhysicsCategoryMask.hero &&
      secondBody.categoryBitMask == PhysicsCategoryMask.package {

      guard let heroNode = firstBody.node as? SKSpriteNode,
        let resourceNode = secondBody.node as? SKShapeNode else { return }
      
      guard let hero = self.entityManager.heroWith(node: heroNode) as? General,
        let impactedResource = self.entityManager.resourceWith(node: resourceNode) as? Package else { return }
      
      guard let heroSpriteComponent = hero.component(ofType: SpriteComponent.self),
        let heroHandsComponent = hero.component(ofType: HandsComponent.self),
        let resourceShapeComponent = impactedResource.component(ofType: ShapeComponent.self),
        !heroHandsComponent.isImpacted else { return }
      
      if heroHandsComponent.hasFreeHand() {
        heroHandsComponent.grab(resource: impactedResource)
        if let resourceIndex = self.entityManager.indexForResource(shape: resourceShapeComponent.node),
          let heroIndex = self.entityManager.playerEntites.firstIndex(of: hero) {
        
          self.multiplayerNetworking
            .sendGrabbedResource(index: resourceIndex,
                                 playerIndex: heroIndex,
                                 senderIndex: self.entityManager.currentPlayerIndex)
        }
      } else {
        hero.impacted()
      }
      
      self.run(SoundManager.shared.blipPaddleSound)
      print("collition occured")
    }
    
    if firstBody.categoryBitMask == PhysicsCategoryMask.hero && secondBody.categoryBitMask == PhysicsCategoryMask.deposit {
      
      guard let heroNode = firstBody.node as? SKSpriteNode,
        let depositNode = secondBody.node as? SKShapeNode else { return }
      
      guard let hero = self.entityManager.heroWith(node: heroNode) as? General,
        let deposit = self.entityManager.enitityWith(node: depositNode) as? Deposit else { return }
      
      guard let handsComponent = hero.component(ofType: HandsComponent.self),
        let teamComponent = hero.component(ofType: TeamComponent.self),
        let spriteComponent = hero.component(ofType: SpriteComponent.self),
        let aliasComponent = hero.component(ofType: AliasComponent.self),
        let depositShapeComponent = deposit.component(ofType: ShapeComponent.self),
        let depositComponent = deposit.component(ofType: DepositComponent.self),
        (handsComponent.leftHandSlot != nil || handsComponent.rightHandSlot != nil) else { return }
        
      var total = 0
      if let lefthanditem = handsComponent.leftHandSlot {
        handsComponent.leftHandSlot = nil
        
        if let shapeComponent = lefthanditem.component(ofType: ShapeComponent.self) {
          shapeComponent.node.removeFromParent()
        }
        
        total += 1
      }
      
      if let rightHandItem = handsComponent.rightHandSlot {
        handsComponent.rightHandSlot = nil
        
        if let shapeComponent = rightHandItem.component(ofType: ShapeComponent.self) {
          shapeComponent.node.removeFromParent()
        }
        
        total += 1
      }
      
      self.entityManager.resourcesDelivered += total
      hero.numberOfDeposits += total
      
      if self.entityManager.currentPlayerIndex < self.multiplayerNetworking.playerAliases.count {
        let alias = self.multiplayerNetworking.playerAliases [self.entityManager.currentPlayerIndex]
        aliasComponent.node.text = "\(alias) (\(hero.numberOfDeposits)/\(resourcesNeededToWin))"
      }
      
      switch teamComponent.team {
      case .team1: depositComponent.team1Deposits += total
      case .team2: depositComponent.team2Deposits += total
      }
      
      if let label = self.gameMessage {
        label.text = "Deposit"
        label.run(SKAction.init(named: "Pulse")!, withKey: "fadeInOut")
      }
      
      if let particles = SKEmitterNode(fileNamed: "Deposit") {
        particles.position = depositShapeComponent.node.position
        particles.zPosition = 3
        self.addChild(particles)
        particles.run(SKAction.sequence([SKAction.wait(forDuration: 1.0), SKAction.removeFromParent()]))
      }
      
      self.run(SoundManager.shared.bambooBreakSound)
      print("deposit occured")
    }
    
    if firstBody.categoryBitMask == PhysicsCategoryMask.hero && secondBody.categoryBitMask == PhysicsCategoryMask.wall {
      
      guard let heroNode = firstBody.node as? SKSpriteNode,
        let beam = secondBody.node as? SKShapeNode else { return }
      
      guard let hero = self.entityManager.heroWith(node: heroNode) as? General,
        let spriteComponent = hero.component(ofType: SpriteComponent.self),
        let physicsComponent = hero.component(ofType: PhysicsComponent.self),
        let impulseComponent = hero.component(ofType: ImpulseComponent.self),
        let panel = self.entityManager.panelWith(node: beam) as? Panel,
        let panelShapeComponent = panel.component(ofType: ShapeComponent.self),
        let tractorBeamComponent = panel.component(ofType: BeamComponent.self),
        !hero.isBeamed && !tractorBeamComponent.isOccupied else { return }

      physicsComponent.isEffectedByPhysics = false
      
      let isTopBeam = beam.position.y == abs(beam.position.y)
      let convertedPosition = self.convert(beam.position, from: panelShapeComponent.node)
      let rotation = isTopBeam ? panelShapeComponent.node.zRotation : panelShapeComponent.node.zRotation + CGFloat.pi
      
      DispatchQueue.main.async {
        spriteComponent.node.position = convertedPosition
        spriteComponent.node.zRotation = rotation
      }
      
      hero.switchToState(.beamed)
      
      hero.occupiedPanel = panel
      tractorBeamComponent.isOccupied = true
      
      if let index = self.entityManager.indexForWall(panel: panel) {
        self.multiplayerNetworking.sendWall(index: index, isOccupied: true)
      }
      impulseComponent.isOnCooldown = false
      
      self.run(SoundManager.shared.blipSound)
      print("wall hit")
    }
  }
}