//
//  TutorialAction.swift
//  ZeroG BattleRoom
//
//  Created by Rudy Gomez on 4/29/20.
//  Copyright © 2020 JRudy Gaming. All rights reserved.
//

import Foundation
import SpriteKit
import GameplayKit


protocol TutorialActionDelegate: AnyObject {
    
  func setupHintAnimations(step: Tutorial.Step)

}
 

class TutorialAction: GKEntity {
  
  var isShowingStep = false
  
  var currentStep: Tutorial.Step? = nil
  private var stepFinished = false {
    didSet {
      guard stepFinished,
        let tapSpriteComponent = component(ofType: SpriteComponent.self) else { return }
      
      tapSpriteComponent.node.removeAllActions()
      
      stepFinished = false
    }
  }
  
  /// The delegate will send messages when the tutorial step should be animated or hidden
  weak var delegate: TutorialActionDelegate?
  
  init(delegate: TutorialActionDelegate? = nil) {
    self.delegate = delegate

    super.init()
    
    let tapComponent = SpriteComponent(texture: SKTexture(imageNamed: "tap"))
    tapComponent.node.name = AppConstants.ComponentNames.tutorialTapStickerName
    tapComponent.node.position = Tutorial.Step.tapLaunch.tapPosition
    tapComponent.node.anchorPoint = CGPoint(x: 0.35, y: 0.9)
    tapComponent.node.zPosition = SpriteZPosition.menu.rawValue
    addComponent(tapComponent)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  @discardableResult
  public func setupNextStep() -> Tutorial.Step? {
    defer { isShowingStep = true }
    
    guard currentStep != nil else {
      delegate?.setupHintAnimations(step: .tapLaunch)
      currentStep = .tapLaunch
      return currentStep
    }
    guard let nextStep = currentStep?.nextStep else {
      return nil
    }
  
    delegate?.setupHintAnimations(step: nextStep)
    currentStep = nextStep
    
    return currentStep
  }
  
}
