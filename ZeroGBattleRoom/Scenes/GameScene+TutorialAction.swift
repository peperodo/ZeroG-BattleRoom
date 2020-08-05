//
//  GameScene+Tutorial.swift
//  ZeroG BattleRoom
//
//  Created by Rudy Gomez on 8/5/20.
//  Copyright © 2020 JRudy Gaming. All rights reserved.
//

import Foundation
import SpriteKit


extension GameScene: TutorialActionDelegate {
  private func hideTutorial() {
    guard let ghost = self.entityManager.playerEntites[1] as? General,
      let ghostSpriteComponent = ghost.component(ofType: SpriteComponent.self),
      let tapSticker = self.childNode(withName: AppConstants.ComponentNames.tutorialTapStickerName),
      let scaledUIContainer = self.cam?.childNode(withName: AppConstants.ComponentNames.tutorialPinchStickerName),
      let pinchSticker = scaledUIContainer.childNode(withName: AppConstants.ComponentNames.tutorialPinchStickerName) else { return }

    ghostSpriteComponent.node.alpha = 0.0
    tapSticker.alpha = 0.0
    pinchSticker.alpha = 0.0
  }
  
  private func showTutorial() {
    guard let tapSticker = self.childNode(withName: AppConstants.ComponentNames.tutorialTapStickerName),
      let scaledUIContainer = self.cam?.childNode(withName: AppConstants.ComponentNames.tutorialPinchStickerName),
      let pinchSticker = scaledUIContainer.childNode(withName: AppConstants.ComponentNames.tutorialPinchStickerName)
      else { return }

    tapSticker.alpha = 1.0
    pinchSticker.alpha = 1.0
  }
  
  func setupHintAnimations(step: Tutorial.Step) {
    guard let ghost = self.entityManager.playerEntites[1] as? General,
      let ghostSpriteComponent = ghost.component(ofType: SpriteComponent.self),
      let physicsComponent = ghost.component(ofType: PhysicsComponent.self),
      let launchComponent = ghost.component(ofType: LaunchComponent.self),
      let tapSticker = self.childNode(withName: AppConstants.ComponentNames.tutorialTapStickerName),
      let scaledUIContainer = self.cam?.childNode(withName: AppConstants.ComponentNames.tutorialPinchStickerName),
      let pinchSticker = scaledUIContainer.childNode(withName: AppConstants.ComponentNames.tutorialPinchStickerName) else { return }
    
    self.stopAllTutorialAnimations()
    self.showTutorial()
    self.repositionSprites(pos: step.startPosition,
                           rotation: step.startRotation,
                           tapPos: step.tapPosition)
    
    let prepareLaunch = SKAction.run {
      launchComponent.launchInfo.lastTouchBegan = step.tapPosition
      ghost.updateLaunchComponents(touchPosition: step.tapPosition)
    }

    let launchGhost = SKAction.run {
      ghost.launch()
    }

    let resetAction = SKAction.run {
      ghostSpriteComponent.node.alpha = 0.0
      ghostSpriteComponent.node.position = step.startPosition
      ghostSpriteComponent.node.zRotation = 0.0
      tapSticker.position = step.tapPosition
      physicsComponent.physicsBody.velocity = .zero
      physicsComponent.physicsBody.angularVelocity = .zero
    }

    switch step {
    case .tapLaunch:
      let launchSequence = SKAction.repeatForever(SKAction.sequence([
        SKAction.wait(forDuration: 2.0),
        prepareLaunch,
        SKAction.wait(forDuration: 2.0),
        launchGhost,
        SKAction.run {
          ShapeFactory.shared.spawnSpinnyNodeAt(pos: step.tapPosition)
        },
        SKAction.wait(forDuration: 4.0),
        resetAction]))

      let tapSequece = SKAction.repeatForever(SKAction.sequence([
        SKAction.fadeOut(withDuration: 0.0),
        SKAction.wait(forDuration: 2.0),
        SKAction.run {
          ghostSpriteComponent.node.alpha = 0.5
        },
        SKAction.fadeIn(withDuration: 0.5),
        SKAction.wait(forDuration: 1.5),
        SKAction.fadeOut(withDuration: 0.5),
        SKAction.wait(forDuration: 3.5)]))

      let runGroup = SKAction.group([launchSequence, tapSequece])
      tapSticker.run(runGroup)
      pinchSticker.run(SKAction.fadeOut(withDuration: 0.0))
    case .pinchZoom:
      let zoomSteps = 30
      let zoomLevel: CGFloat = 1.5
      let zoomTimeInterval: TimeInterval = 0.05
      let pinchOutAction = SKAction.run {
        NotificationCenter.default.post(name: .resizeView, object: zoomLevel)
      }
      let pinchOutSequnce = SKAction.sequence([
        pinchOutAction,
        SKAction.wait(forDuration: zoomTimeInterval)])
      let pinchOut = SKAction.repeat(pinchOutSequnce, count: zoomSteps)

      let pinchInAction = SKAction.run {
        NotificationCenter.default.post(name: .resizeView, object: zoomLevel * -1.0)
      }
      let pinchInSequnce = SKAction.sequence([
        pinchInAction,
        SKAction.wait(forDuration: zoomTimeInterval)])
      let pinchIn = SKAction.repeat(pinchInSequnce, count: zoomSteps)

      let pinchSequence = SKAction.repeatForever(SKAction.sequence([
        SKAction.wait(forDuration: 4.0),
        pinchOut,
        SKAction.wait(forDuration: 2.0),
        pinchIn,
        SKAction.wait(forDuration: 3.0)]))

      let tapAction = SKAction.repeatForever(SKAction.sequence([
        SKAction.fadeOut(withDuration: 0.0),
        SKAction.wait(forDuration: 2.0),
        SKAction.fadeIn(withDuration: 0.5),
        SKAction.wait(forDuration: 1.5),
        SKAction.setTexture(SKTexture(imageNamed: "pinch-in")),
        SKAction.wait(forDuration: 3.5),
        SKAction.setTexture(SKTexture(imageNamed: "pinch-out")),
        SKAction.wait(forDuration: 2.0),
        SKAction.fadeOut(withDuration: 0.5),
        SKAction.wait(forDuration: 2.0)]))

      let runGroup = SKAction.group([pinchSequence, tapAction])
      pinchSticker.run(runGroup)
      tapSticker.run(SKAction.fadeOut(withDuration: 0.0))
    case .swipeLaunch:
      let xMoveDelta: CGFloat = 50.0
      let yMoveDelta: CGFloat = -20.0
      let movePosition = CGPoint(x: step.tapPosition.x + xMoveDelta,
                                 y: step.tapPosition.y + yMoveDelta)
      let launchSequence = SKAction.repeatForever(SKAction.sequence([
        SKAction.wait(forDuration: 2.0),
        prepareLaunch,
        SKAction.wait(forDuration: 3.5),
        launchGhost,
        SKAction.run {
          ShapeFactory.shared.spawnSpinnyNodeAt(pos: movePosition)
        },
        SKAction.wait(forDuration: 4.0),
        resetAction]))

      let swipeAction = SKAction.repeatForever(SKAction.sequence([
        SKAction.fadeOut(withDuration: 0.0),
        SKAction.wait(forDuration: 2.0),
        SKAction.run {
          ghostSpriteComponent.node.alpha = 0.5
        },
        SKAction.fadeIn(withDuration: 0.5),
        SKAction.move(by: CGVector(dx: xMoveDelta, dy: yMoveDelta), duration: 1.5),
        SKAction.wait(forDuration: 1.5),
        SKAction.fadeOut(withDuration: 0.5),
        SKAction.wait(forDuration: 3.5)
      ]))

      let touchUpdateAction = SKAction.sequence([
        SKAction.wait(forDuration: 0.1),
        SKAction.run {
          ghost.updateLaunchComponents(touchPosition: tapSticker.position)
        }])
      let touchAction = SKAction.repeatForever(SKAction.sequence([
        SKAction.wait(forDuration: 2.5),
        SKAction.repeat(touchUpdateAction, count: 15),
        SKAction.wait(forDuration: 5.5)
      ]))

      let runGroup = SKAction.group([launchSequence, swipeAction, touchAction])
      tapSticker.run(runGroup)
      pinchSticker.run(SKAction.fadeOut(withDuration: 0.0))
    case .rotateThrow:
      let xMoveDelta: CGFloat = -50.0
      let yMoveDelta: CGFloat = 0.0
      let movePosition = CGPoint(x: step.tapPosition.x + xMoveDelta,
                                 y: step.tapPosition.y + yMoveDelta)
      let launchSequence = SKAction.repeatForever(SKAction.sequence([
        SKAction.run {
          self.entityManager.spawnResource(position: step.tapPosition, velocity: .zero)
        },
        SKAction.wait(forDuration: 2.0),
        prepareLaunch,
        SKAction.wait(forDuration: 3.5),
        launchGhost,
        SKAction.run {
          ShapeFactory.shared.spawnSpinnyNodeAt(pos: movePosition)
        },
        SKAction.wait(forDuration: 4.0),
        resetAction]))

      let swipeAction = SKAction.repeatForever(SKAction.sequence([
        SKAction.fadeOut(withDuration: 0.0),
        SKAction.wait(forDuration: 2.0),
        SKAction.run {
          ghostSpriteComponent.node.alpha = 0.5
        },
        SKAction.fadeIn(withDuration: 0.5),
        SKAction.move(by: CGVector(dx: xMoveDelta, dy: yMoveDelta), duration: 1.5),
        SKAction.wait(forDuration: 1.5),
        SKAction.fadeOut(withDuration: 0.5),
        SKAction.wait(forDuration: 3.5)
      ]))

      let touchUpdateAction = SKAction.sequence([
        SKAction.wait(forDuration: 0.1),
        SKAction.run {
          ghost.updateLaunchComponents(touchPosition: tapSticker.position)
        }])
      let touchAction = SKAction.repeatForever(SKAction.sequence([
        SKAction.wait(forDuration: 2.5),
        SKAction.repeat(touchUpdateAction, count: 15),
        SKAction.wait(forDuration: 5.5)
      ]))

      let runGroup = SKAction.group([launchSequence, swipeAction, touchAction])
      tapSticker.run(runGroup)
      pinchSticker.run(SKAction.fadeOut(withDuration: 0.0))
    }
  }
  
  func stopAllTutorialAnimations() {
    guard let ghost = self.entityManager.playerEntites[1] as? General,
      let ghostSpriteComponent = ghost.component(ofType: SpriteComponent.self),
      let tapSticker = self.childNode(withName: AppConstants.ComponentNames.tutorialTapStickerName),
      let scaledUIContainer = self.cam?.childNode(withName: AppConstants.ComponentNames.tutorialPinchStickerName),
      let pinchSticker = scaledUIContainer.childNode(withName: AppConstants.ComponentNames.tutorialPinchStickerName) else { return }
    
    tapSticker.removeAllActions()
    ghostSpriteComponent.node.removeAllActions()
    pinchSticker.removeAllActions()
    
    self.hideTutorial()
  }
  
  private func repositionSprites(pos: CGPoint, rotation: CGFloat, tapPos: CGPoint) {
    guard let hero = self.entityManager.hero as? General,
      let heroSpriteComponent = hero.component(ofType: SpriteComponent.self),
      let ghost = self.entityManager.playerEntites[1] as? General,
      let spriteComponent = ghost.component(ofType: SpriteComponent.self),
      let tapSticker = self.childNode(withName: AppConstants.ComponentNames.tutorialTapStickerName) else { return }

    DispatchQueue.main.async {
      tapSticker.position = tapPos
      spriteComponent.node.position = pos
      spriteComponent.node.zRotation = rotation
      heroSpriteComponent.node.position = pos
      heroSpriteComponent.node.zRotation = rotation
    }
  }
}