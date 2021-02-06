//
//  EntityManager.swift
//  ZeroG BattleRoom
//
//  Created by Rudy Gomez on 4/4/20.
//  Copyright © 2020 JRudy Gaming. All rights reserved.
//

import Foundation
import SpriteKit
import GameplayKit


let numberOfSpawnedResources = 10
let resourcesNeededToWin = 3
let minDriftVelocity: CGFloat = 5.0
let resourcePullDamper: CGFloat = 0.015

class EntityManager {
  
  lazy var componentSystems: [GKComponentSystem] = {
    let aliasComponent = GKComponentSystem(componentClass: AliasComponent.self)
    let interfaceComponent = GKComponentSystem(componentClass: InterfaceComponent.self)
    return [aliasComponent, interfaceComponent]
  }()
  
  var playerEntites: [GKEntity] = [
    General(imageName: "spaceman-idle-0", team: .team1),
    General(imageName: "spaceman-idle-0", team: .team2)
  ]
  var resourcesEntities = [GKEntity]()
  var wallEntities = [GKEntity]()
  var tutorialEntities = [GKEntity]()
  var uiEntities = Set<GKEntity>()
  var entities = Set<GKEntity>()
  var toRemove = Set<GKEntity>()
  
  var currentPlayerIndex = 0
  var isHost: Bool { currentPlayerIndex == 0 }
  
  var hero: GKEntity? {
    guard self.playerEntites.count > 0 else { return nil }
    guard self.currentPlayerIndex < self.playerEntites.count else { return nil }
    
    return self.playerEntites[self.currentPlayerIndex]
  }
  
  var deposit: GKEntity? {
    let deposit = self.entities.first { entity -> Bool in
      guard let _ = entity as? Deposit else { return false }
      
      return true
    }
    return deposit
  }
  
  var winningTeam: Team? {
    guard let deposit = self.deposit as? Deposit,
      let depositComponent = deposit.component(ofType: DepositComponent.self) else { return nil }
    
    if depositComponent.team1Deposits >= resourcesNeededToWin {
      return Team.team1
    }
    
    if depositComponent.team2Deposits >= resourcesNeededToWin {
      return Team.team2
    }
    
    return nil
  }
  
  var panelFactory = PanelFactory()
  
  private var resourceNode : SKShapeNode?
  
  unowned let scene: GameScene
  
  init(scene: GameScene) {
    self.scene = scene
    
    self.createResourceNode()
  }
  
  func add(_ entity: GKEntity) {
    self.entities.insert(entity)
    
    if let spriteNode = entity.component(ofType: SpriteComponent.self)?.node {
      self.scene.addChild(spriteNode)
    }
    
    if let shapeNode = entity.component(ofType: ShapeComponent.self)?.node {
      self.scene.addChild(shapeNode)
    }
    
    if let trailNode = entity.component(ofType: TrailComponent.self)?.node {
      self.scene.addChild(trailNode)
    }
    
    self.addToComponentSysetem(entity: entity)
  }
  
  func remove(_ entity: GKEntity) {
    if let spriteNode = entity.component(ofType: SpriteComponent.self)?.node {
      spriteNode.removeFromParent()
    }
    
    if let shapeNode = entity.component(ofType: ShapeComponent.self)?.node {
      shapeNode.removeFromParent()
    }
    
    if let trailNode = entity.component(ofType: TrailComponent.self)?.node {
      trailNode.removeFromParent()
    }
    
    self.entities.remove(entity)
    self.toRemove.insert(entity)
  }
  
  func removeAllResourceEntities() {
    print("removing all resources")
    for entity in self.resourcesEntities {
      if let shapeComponent = entity.component(ofType: ShapeComponent.self) {
        shapeComponent.node.removeFromParent()
      }
    }
    self.resourcesEntities.removeAll()
  }
  
  private func addToComponentSysetem(entity: GKEntity) {
    for componentSystem in self.componentSystems {
      componentSystem.addComponent(foundIn: entity)
    }
  }
  
  func update(_ deltaTime: CFTimeInterval) {
    for entity in uiEntities {
      if let scaledComponent = entity as? ScaledContainer {
        scaledComponent.updateViewPort(size: self.scene.viewportSize)
      }
    }
    
    for componentSystem in self.componentSystems {
      componentSystem.update(deltaTime: deltaTime)
    }
    
    for currentRemove in toRemove {
      for componentSystem in self.componentSystems {
        componentSystem.removeComponent(foundIn: currentRemove)
      }
    }
    self.toRemove.removeAll()
    
    self.updateUIElements()
    self.updateResourceVelocity()
  }
  
  private func updateUIElements() {
    guard let restartButton = self.scene.cam?.childNode(withName: AppConstants.ButtonNames.refreshButtonName) else { return }
    
    guard let hero = self.playerEntites[0] as? General,
      let heroSpriteComponent = hero.component(ofType: SpriteComponent.self),
      let physicsBody = heroSpriteComponent.node.physicsBody,
      !hero.isBeamed else { return }
    
    let absDx = abs(physicsBody.velocity.dx)
    let absDy = abs(physicsBody.velocity.dy)
    let notMoving = absDx < minDriftVelocity && absDy < minDriftVelocity
//    restartButton.alpha = notMoving ? 1.0 : 0.0
  }
  
  private func updateResourceVelocity() {
    guard let deposit = self.scene.childNode(withName: AppConstants.ComponentNames.depositNodeName) else { return }
  
    for resource in self.resourcesEntities {
      guard let package = resource as? Package,
        let physicsComponent = package.component(ofType: PhysicsComponent.self),
        let shapeComponent = package.component(ofType: ShapeComponent.self) else { return }
    
      let dx = deposit.position.x - shapeComponent.node.position.x
      let dy = deposit.position.y - shapeComponent.node.position.y
      let distanceToDeposit = sqrt(pow(dx, 2.0) + pow(dy, 2.0))

      if distanceToDeposit < Deposit.eventHorizon {
        self.scene.handleDeposit(package: package)
      } else if distanceToDeposit < Deposit.pullDistance && !isHeld(resource: package) {
        let pullStength = (Deposit.pullDistance - distanceToDeposit) * resourcePullDamper
        let moveX = deposit.position.x - shapeComponent.node.position.x
        let moveY = deposit.position.y - shapeComponent.node.position.y
        let moveVector = CGVector(dx:  moveX, dy: moveY)
        let adjustedVector = moveVector.normalized() * pullStength
        physicsComponent.physicsBody.applyImpulse(adjustedVector)
      } else if package.wasThrownBy == nil && !(self.scene.gameState.currentState is Tutorial) {
        let xSpeed = sqrt(physicsComponent.physicsBody.velocity.dy * physicsComponent.physicsBody.velocity.dx)
        let ySpeed = sqrt(physicsComponent.physicsBody.velocity.dy * physicsComponent.physicsBody.velocity.dy)
        
        let speed = sqrt(physicsComponent.physicsBody.velocity.dx * physicsComponent.physicsBody.velocity.dx + physicsComponent.physicsBody.velocity.dy * physicsComponent.physicsBody.velocity.dy)
        
        if xSpeed <= 10.0 {
          physicsComponent.randomImpulse(y: 0.0)
        }
        
        if ySpeed <= 10.0 {
          physicsComponent.randomImpulse(x: 0.0)
        }
        
        physicsComponent.physicsBody.linearDamping = speed > Package.maxSpeed ? 0.4 : 0.0
      }
    }
  }
  
  private func isHeld(resource: Package) -> Bool {
    var isHeld = false
    playerEntites.forEach { player in
      guard isHeld == false else { return }
      guard let hero = player as? General,
            let heroHands = hero.component(ofType: HandsComponent.self),
            let shape = resource.component(ofType: ShapeComponent.self) else { return }
      
      // NOTE: Why does isHolding(resource:) not match?
      if heroHands.leftHandSlot != nil || heroHands.rightHandSlot != nil { isHeld = true}
    }
    
    return isHeld
  }
  
  func isScored(resource: Package) -> Bool {
    var isScored = false
    playerEntites.forEach { player in
      guard isScored == false else { return }
      guard let deliveredComponent = player.component(ofType: DeliveredComponent.self) else { return }
      
      if deliveredComponent.resources.contains(resource) { isScored = true }
    }
    
    return isScored
  }
}

extension EntityManager {
  func spawnHeros(mapSize: CGSize) {
    let heroBlue = self.playerEntites[0]
    if let spriteComponent = heroBlue.component(ofType: SpriteComponent.self),
      let trailComponent = heroBlue.component(ofType: TrailComponent.self),
      let aliasComponent = heroBlue.component(ofType: AliasComponent.self),
      let handsComponent = heroBlue.component(ofType: HandsComponent.self) {
      
      handsComponent.didRemoveResource = { resource in
        guard let shapeComponent = resource.component(ofType: ShapeComponent.self) else { return }
        
        self.scene.addChild(shapeComponent.node)
      }
      
      spriteComponent.node.position = CGPoint(x: 0.0, y: -mapSize.height/2 + 20)
      spriteComponent.node.zPosition = SpriteZPosition.hero.rawValue
      self.scene.addChild(spriteComponent.node)
      
      self.scene.addChild(trailComponent.node)
      
      aliasComponent.node.text = self.scene.getPlayerAliasAt(index: 0)
      self.scene.addChild(aliasComponent.node)
    }

    self.addToComponentSysetem(entity: heroBlue)
    
    let heroRed = self.playerEntites[1]
    if let spriteComponent = heroRed.component(ofType: SpriteComponent.self),
      let trailComponent = heroRed.component(ofType: TrailComponent.self),
      let aliasComponent = heroRed.component(ofType: AliasComponent.self),
      let handsComponent = heroRed.component(ofType: HandsComponent.self) {
      
      handsComponent.didRemoveResource = { resource in
        guard let shapeComponent = resource.component(ofType: ShapeComponent.self) else { return }
        
        self.scene.addChild(shapeComponent.node)
      }
      
      spriteComponent.node.position = CGPoint(x: 0.0, y: mapSize.height/2 - 20)
      spriteComponent.node.zPosition = SpriteZPosition.hero.rawValue
      spriteComponent.node.zRotation = CGFloat.pi
      self.scene.addChild(spriteComponent.node)
      
      self.scene.addChild(trailComponent.node)
      
      aliasComponent.node.text = self.scene.getPlayerAliasAt(index: 1)
      self.scene.addChild(aliasComponent.node)
    }

    self.addToComponentSysetem(entity: heroRed)
  }
  
  func spawnResources() {
    guard isHost else { return }
    
    for _ in 0..<numberOfSpawnedResources {
      self.spawnResource()
    }
  }
  
  func spawnResource(position: CGPoint = AppConstants.Layout.boundarySize.randomPosition,
                     velocity: CGVector? = nil) {
    guard let resourceNode = self.resourceNode?.copy() as? SKShapeNode else { return }
    
    let resource = Package(shapeNode: resourceNode,
                           physicsBody: self.resourcePhysicsBody(frame: resourceNode.frame))
    if let physicsComponent = resource.component(ofType: PhysicsComponent.self) {
      
      self.scene.addChild(resourceNode)
      resourceNode.position = position
      DispatchQueue.main.async {
        if let vector = velocity {
          physicsComponent.physicsBody.velocity = vector
        } else {
          physicsComponent.randomImpulse()
        }
      }
    }
    
    resourceNode.strokeColor = SKColor.green
    self.resourcesEntities.append(resource)
  }
  
  private func resourcePhysicsBody(frame: CGRect) -> SKPhysicsBody {
    let radius = frame.size.height / 2.0
    
    let physicsBody = SKPhysicsBody(circleOfRadius: radius)
    physicsBody.friction = 0.0
    physicsBody.restitution = 1.0
    physicsBody.linearDamping = 0.0
    physicsBody.angularDamping = 0.0
    physicsBody.categoryBitMask = PhysicsCategoryMask.package
  
    // Make sure resources are only colliding on the designated host device
    if isHost {
      physicsBody.contactTestBitMask = PhysicsCategoryMask.hero | PhysicsCategoryMask.wall
      physicsBody.collisionBitMask = PhysicsCategoryMask.hero | PhysicsCategoryMask.package
    } else {
      physicsBody.contactTestBitMask = 0
      physicsBody.collisionBitMask = 0
    }
    
    return physicsBody
  }
    
  func spawnDeposit(position: CGPoint = .zero) {
    let deposit = Deposit()
    
    guard let shapeComponent = deposit.component(ofType: ShapeComponent.self) else { return }
    
    shapeComponent.node.position = position
    self.add(deposit)
  }
  
  func spawnPanels() {
    let factory = self.scene.entityManager.panelFactory
    let wallPanels = factory.perimeterWallFrom(size: AppConstants.Layout.boundarySize)
    let centerPanels = self.centerPanels()
    let blinderPanels = self.blinderPanels()
    let extraPanels = self.extraPanels()
    
    for entity in wallPanels + centerPanels + blinderPanels + extraPanels {
      if let shapeNode = entity.component(ofType: ShapeComponent.self)?.node {
        self.scene.addChild(shapeNode)
      }
      self.wallEntities.append(entity)
    }
  }
  
  private func centerPanels() -> [GKEntity] {
    let position = CGPoint(x: 75.0, y: 130.0)
    let topLeftPosition = CGPoint(x: -position.x, y: position.y)
    let topLeftWall = self.panelFactory.panelSegment(beamConfig: .both,
                                                     number: 2,
                                                     position: topLeftPosition,
                                                     orientation: .risingDiag)
    let topRightPosition = CGPoint(x: position.x, y: position.y)
    let topRightWall = self.panelFactory.panelSegment(beamConfig: .both,
                                                      number: 2,
                                                      position: topRightPosition,
                                                      orientation: .fallingDiag)
    let bottomLeftPosition = CGPoint(x: -position.x, y: -position.y)
    let bottomLeftWall = self.panelFactory.panelSegment(beamConfig: .both,
                                                        number: 2,
                                                        position: bottomLeftPosition,
                                                        orientation: .fallingDiag)
    let bottomRightPosition = CGPoint(x: position.x, y: -position.y)
    let bottomRightWall = self.panelFactory.panelSegment(beamConfig: .both,
                                                         number: 2,
                                                         position: bottomRightPosition,
                                                         orientation: .risingDiag)

    return topLeftWall + topRightWall + bottomLeftWall + bottomRightWall
  }
  
  private func blinderPanels() -> [GKEntity] {
    let yPosRatio: CGFloat = 0.3
    let numberOfSegments = 5
    let topBlinderPosition = CGPoint(x: 0.0,
                                     y: AppConstants.Layout.boundarySize.height * yPosRatio)
    let topBlinder = self.panelFactory.panelSegment(beamConfig: .both,
                                                    number: numberOfSegments,
                                                    position: topBlinderPosition)
    
    let bottomBlinderPosition = CGPoint(x: 0.0,
                                        y: -AppConstants.Layout.boundarySize.height * yPosRatio)
    let bottomBlinder = self.panelFactory.panelSegment(beamConfig: .both,
                                                       number: numberOfSegments,
                                                       position: bottomBlinderPosition)
    return topBlinder + bottomBlinder
  }
  
  private func extraPanels() -> [GKEntity] {
    let width = AppConstants.Layout.boundarySize.width
    let wallLength = AppConstants.Layout.wallSize.width
    let numberOfSegments = 2
  
    let leftBlinderPosition = CGPoint(x: -width / 2 + wallLength + 10, y: 0.0)
    let leftBlinder = self.panelFactory.panelSegment(beamConfig: .both,
                                                     number: numberOfSegments,
                                                     position: leftBlinderPosition)
 
    let rightBlinderPosition = CGPoint(x: width / 2 - wallLength - 10, y: 0.0)
    let rightBlinder = self.panelFactory.panelSegment(beamConfig: .both,
                                                      number: numberOfSegments,
                                                      position: rightBlinderPosition)
    return leftBlinder + rightBlinder
  }
}

extension EntityManager {
  private func createResourceNode() {
    let width: CGFloat = 10.0
    let size = CGSize(width: width, height: width)
    
    self.resourceNode = SKShapeNode(rectOf: size, cornerRadius: width * 0.3)
    guard let resourceNode = self.resourceNode else { return }
    
    resourceNode.name = AppConstants.ComponentNames.resourceName
    resourceNode.lineWidth = 2.5
  }
}

extension EntityManager {
  func heroWith(node: SKSpriteNode) -> GKEntity? {
    let player = self.playerEntites.first { entity -> Bool in
      guard let hero = entity as? General else { return false }
      guard let spriteComponent = hero.component(ofType: SpriteComponent.self) else { return false }
      
      return spriteComponent.node === node
    }
    
    return player
  }
  
  func resourceWith(node: SKShapeNode) -> GKEntity? {
    let resource = self.resourcesEntities.first { entity -> Bool in
      guard let package = entity as? Package else { return false }
      guard let shapeComponent = package.component(ofType: ShapeComponent.self) else { return false }
      
      return shapeComponent.node === node
    }
    
    return resource
  }
  
  func panelWith(node: SKShapeNode) -> GKEntity? {
    let panel = self.wallEntities.first { entity -> Bool in
      guard let panelEntity = entity as? Panel,
        let beamComponent = panelEntity.component(ofType: BeamComponent.self) else { return false }
      
      let beam = beamComponent.beams.first { beam -> Bool in
        return beam === node
      }
  
      return beam == nil ? false : true
    }
    
    return panel
  }
  
  func enitityWith(node: SKNode) -> GKEntity? {
    let entity = self.entities.first { entity -> Bool in
      switch node {
      case is SKSpriteNode:
        guard let hero = entity as? General else { return false }
        guard let spriteComponent = hero.component(ofType: SpriteComponent.self) else { return  false }
        
        return spriteComponent.node === node
      case is SKShapeNode:
        switch entity {
        case is Deposit:
          guard let deposit = entity as? Deposit,
            let shapeComponent = deposit.component(ofType: ShapeComponent.self) else { return false }
          
          return shapeComponent.node === node
          
        default: break
        }
      default: break
      }
      
      return false
    }
    return entity
  }
  
  func uiEntityWith(nodeName: String) -> GKEntity? {
    let element = self.uiEntities.first { entity -> Bool in
      guard let uiEntity = entity as? ScaledContainer else { return false }

      return uiEntity.node.name == nodeName
    }
    
    return element
  }
  
  func indexForResource(shape: SKShapeNode) -> Int? {
    let index = self.resourcesEntities.firstIndex { entity -> Bool in
      guard let package = entity as? Package else { return false }
      guard let shapeComponent = package.component(ofType: ShapeComponent.self) else { return  false }
      
      return shapeComponent.node === shape
    }
    
    return index
  }
  
  func indexForWall(panel: Panel) -> Int? {
    let index = self.wallEntities.firstIndex { entity -> Bool in
      guard let wall = entity as? Panel else { return false }
      return wall == panel
    }
    
    return index
  }
}

extension EntityManager {
  
  // MARK: - UI Setup Methods
  
  func addUIElements() {
    self.setupBackButton()
    self.setupRestartButton()
    
    if self.scene.gameState.currentState is Tutorial {
      self.addTutorialStickers()
    }
  }
  
  private func addTutorialStickers() {
    let tapSticker = SKSpriteNode(imageNamed: "throw")
    tapSticker.name = AppConstants.ButtonNames.throwButtonName
    tapSticker.alignMidRight()
    tapSticker.zPosition = SpriteZPosition.inGameUI.rawValue
    tapSticker.alpha = 0.5
    
    let throwTapSticker = SKSpriteNode(imageNamed: "tap")
    throwTapSticker.name = AppConstants.ComponentNames.tutorialThrowStickerName
    throwTapSticker.zPosition = SpriteZPosition.inGameUI2.rawValue
    throwTapSticker.anchorPoint = CGPoint(x: 0.2, y: 0.9)
    throwTapSticker.alignMidRight()
    throwTapSticker.alpha = 0.0
    
    let pinchSticker = SKSpriteNode(imageNamed: "pinch-out")
    pinchSticker.name = AppConstants.ComponentNames.tutorialPinchStickerName
    pinchSticker.position = CGPoint(x: 50.0, y: -100.0)
    pinchSticker.anchorPoint = CGPoint(x: 0.2, y: 0.9)
    pinchSticker.zPosition = SpriteZPosition.inGameUI.rawValue
    
    self.addInGameUIViews(elements: [tapSticker, throwTapSticker, pinchSticker])
  }
  
  func removeUIElements() {
    self.removeInGameUIViewElements()
  }
  
  private func setupBackButton() {
    let backButton = SKShapeNode(rect: AppConstants.Layout.buttonRect,
                                 cornerRadius: AppConstants.Layout.buttonCornerRadius)
    backButton.name = AppConstants.ButtonNames.backButtonName
    backButton.zPosition = SpriteZPosition.menu.rawValue
    backButton.fillColor = AppConstants.UIColors.buttonBackground
    backButton.strokeColor = AppConstants.UIColors.buttonForeground
    backButton.alignTopLeft()
    
    let imageNode = SKSpriteNode(imageNamed: "back-white")
    imageNode.name = AppConstants.ButtonNames.backButtonName
    imageNode.zPosition = SpriteZPosition.menuLabel.rawValue
    imageNode.scale(to: backButton.frame.size)
    imageNode.color = AppConstants.UIColors.buttonForeground
    imageNode.colorBlendFactor = 1
    backButton.addChild(imageNode)
  
    self.addInGameUIView(element: backButton)
  }
  
  private func setupRestartButton() {
    let restartButton = SKShapeNode(rect: AppConstants.Layout.buttonRect,
                                    cornerRadius: AppConstants.Layout.buttonCornerRadius)
    restartButton.name = AppConstants.ButtonNames.refreshButtonName
    restartButton.zPosition = SpriteZPosition.menu.rawValue
    restartButton.fillColor = AppConstants.UIColors.buttonBackground
    restartButton.strokeColor = AppConstants.UIColors.buttonForeground
    restartButton.alignMidBottom()
    
    let imageNode = SKSpriteNode(imageNamed: "refresh-white")
    imageNode.name = AppConstants.ButtonNames.refreshButtonName
    imageNode.zPosition = SpriteZPosition.menuLabel.rawValue
    imageNode.scale(to: restartButton.frame.size)
    imageNode.color = AppConstants.UIColors.buttonForeground
    imageNode.colorBlendFactor = 1
    restartButton.addChild(imageNode)
  
    self.addInGameUIView(element: restartButton)
  }
  
  private func addInGameUIViews(elements: [SKNode]) {
    for element in elements {
      self.addInGameUIView(element: element)
    }
  }
  
  private func addInGameUIView(element: SKNode) {
    let scaledComponent = ScaledContainer(element: element)
    
    self.scene.cam!.addChild(scaledComponent.node)
    
    self.uiEntities.insert(scaledComponent)
    self.addToComponentSysetem(entity: scaledComponent)
  }
  
  private func removeInGameUIViewElements() {
    for entity in self.uiEntities {
      if let scalableElement = entity as? ScaledContainer {
        self.toRemove.insert(scalableElement)
      }
    }
  
    self.uiEntities.removeAll()
  }
}

extension EntityManager {
  
  // MARK: - Tutorial Spawn Methods
  
  func spawnTutorialPanels() {
    let factory = self.scene.entityManager.panelFactory
    
    let wallSize = AppConstants.Layout.wallSize
    let size = CGSize(width: 100.0 + wallSize.height, height: 400.0)
    
    let widthSegments = factory.numberOfSegments(length: size.width, wallSize: wallSize.width)
    let heightSegments = factory.numberOfSegments(length: size.height, wallSize: wallSize.width)

    let leftWall = factory.panelSegment(beamConfig: .none,
                                        number: heightSegments,
                                        position: CGPoint(x: -size.width/2, y: 0.0),
                                        orientation: .vertical)
    let rightWall = factory.panelSegment(beamConfig: .none,
                                         number: heightSegments,
                                         position: CGPoint(x: size.width/2, y: 0.0),
                                         orientation: .vertical)
    let bottomRightCorner = factory.panelSegment(beamConfig: .none,
    number: 1,
    position: CGPoint(x: size.width/2 - wallSize.width/2,
                      y: size.height/2))
    let topLeftCorner = factory.panelSegment(beamConfig: .none,
                                             number: 1,
                                             position: CGPoint(x: -size.width/2 + wallSize.width/2,
                                                               y: -size.height/2))
    let topRightCorner = factory.panelSegment(beamConfig: .none,
                                              number: 1,
                                              position: CGPoint(x: size.width/2 - wallSize.width/2,
                                                                y: -size.height/2))
    let bottomLeftCorner = factory.panelSegment(beamConfig: .none,
                                                number: 1,
                                                position: CGPoint(x: -size.width/2 + wallSize.width/2,
                                                                  y: size.height/2))
    let player1Base1 = factory.panelSegment(beamConfig: .top,
                                            number: 1,
                                            position: CGPoint(x: 0.0, y: -size.height/2),
                                            team: .team1)
    let player2Base1 = factory.panelSegment(beamConfig: .bottom,
                                            number: 1,
                                            position: CGPoint(x: 0.0, y: size.height/2),
                                            team: .team2)
    
    let corners = topLeftCorner + topRightCorner + bottomLeftCorner + bottomRightCorner
    for entity in leftWall + rightWall/* + corners*/ + player1Base1 + player2Base1 {
      self.add(entity)
      self.wallEntities.append(entity)
    }
  }
  
  func loadTutorialLevel() {
    guard let scene = SKScene(fileNamed: "TutorialScene") else { return }
    
    scene.enumerateChildNodes(withName: AppConstants.ComponentNames.wallPanelName) { wallNode, _  in
      var team: Team? = nil
      if let userData = wallNode.userData, let teamRawValue = userData[Tutorial.teamUserDataKey] as? Int {
        team = Team(rawValue: teamRawValue)
      }
      
      var config: Panel.BeamArrangment = .none
      if let userData = wallNode.userData,
        let beamsRawValue = userData[Tutorial.beamsUserDataKey] as? Int {
        
        config = Panel.BeamArrangment(rawValue: beamsRawValue)!
      }
      
      guard let panel = self.scene.entityManager.panelFactory.panelSegment(beamConfig: config,
                                                                           number: 1,
                                                                           team: team).first,
        let panelShapeComponent = panel.component(ofType: ShapeComponent.self) else { return }
      
      panelShapeComponent.node.position = wallNode.position
      panelShapeComponent.node.zRotation = wallNode.zRotation
      
      self.scene.addChild(panelShapeComponent.node)
      self.wallEntities.append(panel)
    }
  }
  
  func setupTutorial() {
    guard let hero = self.playerEntites[0] as? General,
      let heroAliasComponent = hero.component(ofType: AliasComponent.self),
      let heroSpriteComponent = hero.component(ofType: SpriteComponent.self),
      let heroPhysicsComponent = hero.component(ofType: PhysicsComponent.self),
      let ghost = self.playerEntites[1] as? General,
      let ghostAliasComponent = ghost.component(ofType: AliasComponent.self),
      let ghostSpriteComponent = ghost.component(ofType: SpriteComponent.self),
      let ghostPhysicsComponent = ghost.component(ofType: PhysicsComponent.self) else { return }
    
    heroAliasComponent.node.text = ""
    ghostAliasComponent.node.text = ""
    
    ghost.switchToState(.moving)
    ghostSpriteComponent.node.alpha = 0.5
    ghostPhysicsComponent.physicsBody.collisionBitMask = PhysicsCategoryMask.package
    heroPhysicsComponent.physicsBody.collisionBitMask = PhysicsCategoryMask.package
    
    let tutorialActionEntity = TutorialAction(delegate: self.scene)
    if let tapSpriteComponent = tutorialActionEntity.component(ofType: SpriteComponent.self) {
      self.scene.addChild(tapSpriteComponent.node)
    }
    
    if let step = tutorialActionEntity.setupNextStep(), step == .rotateThrow {
      spawnResource(position: step.midPosition, velocity: .zero)
    }
    
    self.tutorialEntities.append(tutorialActionEntity)
  }
}
