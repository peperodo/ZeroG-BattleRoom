//
//  Playing.swift
//  SpaceMonkies
//
//  Created by Rudy Gomez on 3/26/20.
//  Copyright © 2020 JRudy Gaming. All rights reserved.
//

import Foundation
import GameplayKit

class Playing: GKState {
  
  let wallNodeName = "wall"
  
  enum Level: Int {
    case level_1 = 1
    case level_2
    case level_3
    
    var filename: String {
      return "Level_\(self.rawValue)"
    }
  }
  
  unowned let scene: GameScene
  
  init(scene: SKScene) {
    self.scene = scene as! GameScene
    super.init()
  }
  
  override func didEnter(from previousState: GKState?) {
    self.setupCamera()
    self.setupPhysics()
  
    self.scene.entityManager.spawnPanels()
    
//    self.loadLevel()
    
//    self.spawnResources()
    if self.scene.viewModel.currentPlayerIndex == 0 {
      for _ in 0..<numberOfSpawnedResources {
        self.scene.entityManager.spawnResource()
      }
    }
    
    self.scene.entityManager.spawnHeros()
    self.scene.entityManager.spawnDeposit()
  }
  
  override func willExit(to nextState: GKState) { }
  
  override func isValidNextState(_ stateClass: AnyClass) -> Bool {
    return stateClass is GameOver.Type
  }

  override func update(deltaTime seconds: TimeInterval) {
    self.repositionCamera()
  }
  
  private func loadLevel(_ level: Level = .level_1) {
    guard let scene = SKScene(fileNamed: level.filename) else { return }
    
    scene.enumerateChildNodes(withName: AppConstants.ComponentNames.wallPanelName) { wallNode, _  in
      if let wall = self.scene.viewModel.wallNodeCopy {
        wall.position = wallNode.position
        wall.zRotation = wallNode.zRotation
        self.scene.addChild(wall)
      }
    }
  }
}

extension Playing {
  private func setupPhysics() {
    self.scene.physicsBody = self.scene.viewModel.borderBody
    self.scene.physicsWorld.gravity = CGVector(dx: 0.0, dy: 0.0)
    self.scene.physicsWorld.contactDelegate = self.scene
  }
  
  private func setupCamera() {
    self.scene.cam = SKCameraNode()
    self.scene.camera = self.scene.cam
    self.scene.addChild(self.scene.cam!)
  }
}

extension Playing {
  private func repositionCamera() {
    guard let camera = self.scene.cam else { return }
    guard let hero = self.scene.entityManager.hero as? General else { return }
    guard let spriteComponent = hero.component(ofType: SpriteComponent.self) else { return }
    
    let sideEdge = AppConstants.Layout.mapSize.width / 2
    let frameSideEdge = self.scene.frame.size.width / 2
    if sideEdge - abs(spriteComponent.node.position.x) > frameSideEdge {
      camera.position.x = spriteComponent.node.position.x
    }
    
    let topEdge = AppConstants.Layout.mapSize.height / 2
    let frameTopEdge = self.scene.frame.size.height / 2
    if topEdge - abs(spriteComponent.node.position.y) > frameTopEdge {
      camera.position.y = spriteComponent.node.position.y
    }
  }
}
