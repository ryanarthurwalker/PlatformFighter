//
//  GameScene.swift
//  PlatformFighter
//
//  Created by Ryan Walker on 12/7/24.
//

import SpriteKit
import GameController


class GameScene: SKScene, SKPhysicsContactDelegate {
    
    var player: SKSpriteNode!
    var enemy: SKSpriteNode!
    
    var horizontalVelocity: CGFloat = 0
    let maxSpeed: CGFloat = 300
    let maxRunSpeed: CGFloat = 400
    let acceleration: CGFloat = 20
    let deceleration: CGFloat = 30
    var isMovingLeft = false
    var isMovingRight = false
    var isFastFalling = false
    var jumpHeld = false
    var jumpBufferTime: CGFloat = 0.2 // Buffer duration in seconds
    var jumpBufferCounter: CGFloat = 0.0
    var jumpQueued = false
    var jumpHoldTime: CGFloat = 0.3 // Maximum duration to hold jump for a full jump
    var jumpHoldCounter: CGFloat = 0.0
    let blastZonePadding: CGFloat = 200 // Distance outside the visible screen
    
    let shortHopImpulse: CGFloat = 500
    let fullJumpImpulse: CGFloat = 200
    let fastFallSpeed: CGFloat = -500
    
    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
        backgroundColor = .white
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -40)
        physicsWorld.contactDelegate = self
        
        createPlatforms()
        createPlayer()
        createEnemy()
        setupControllerSupport()
    }
    
    func createPlatforms() {
        let platform = SKSpriteNode(color: .brown, size: CGSize(width: 600, height: 20))
        platform.name = "platform"
        platform.position = CGPoint(x: 0, y: -size.height / 6)
        platform.physicsBody = SKPhysicsBody(rectangleOf: platform.size)
        platform.physicsBody?.isDynamic = false
        addChild(platform)
        createEdge(for: platform)
    }
    
    func createEdge(for platform: SKSpriteNode) {
        // Left edge
        let leftEdge = SKSpriteNode(color: .clear, size: CGSize(width: 10, height: platform.size.height / 2))
        leftEdge.name = "leftEdge"
        leftEdge.position = CGPoint(
            x: platform.position.x - platform.size.width / 2,
            y: platform.position.y - platform.size.height / 2
        )
        leftEdge.physicsBody = SKPhysicsBody(rectangleOf: leftEdge.size)
        leftEdge.physicsBody?.isDynamic = false
        leftEdge.physicsBody?.categoryBitMask = PhysicsCategory.edge
        leftEdge.physicsBody?.contactTestBitMask = PhysicsCategory.player
        leftEdge.physicsBody?.collisionBitMask = 0
        addChild(leftEdge)

        // Right edge
        let rightEdge = SKSpriteNode(color: .clear, size: CGSize(width: 10, height: platform.size.height / 2))
        rightEdge.name = "rightEdge"
        rightEdge.position = CGPoint(
            x: platform.position.x + platform.size.width / 2,
            y: platform.position.y - platform.size.height / 2
        )
        rightEdge.physicsBody = SKPhysicsBody(rectangleOf: rightEdge.size)
        rightEdge.physicsBody?.isDynamic = false
        rightEdge.physicsBody?.categoryBitMask = PhysicsCategory.edge
        rightEdge.physicsBody?.contactTestBitMask = PhysicsCategory.player
        rightEdge.physicsBody?.collisionBitMask = 0
        addChild(rightEdge)
    }
    
    func createPlayer() {
        // Replace the rectangle with a texture-based sprite
        let playerTexture = SKTexture(imageNamed: "CharacterSprite") // Replace "CharacterSprite" with your image name
        player = SKSpriteNode(texture: playerTexture)
        player.size = CGSize(width: 80, height: 80) // Adjust to fit your sprite's design
        player.name = "player"
        player.position = CGPoint(x: 0, y: 0) // Starting position

        player.physicsBody = SKPhysicsBody(rectangleOf: player.size) // Use rectangle physics
        player.physicsBody?.allowsRotation = false // Prevent spinning

        // Assign physics bitmasks
        player.physicsBody?.categoryBitMask = PhysicsCategory.player // Define what this object is (player)
        player.physicsBody?.contactTestBitMask = PhysicsCategory.platform | PhysicsCategory.edge // Detect collisions with platforms or edges
        player.physicsBody?.collisionBitMask = PhysicsCategory.platform // Define objects the player can collide with

           // Add the player to the scene
           addChild(player)
       }
    
    func createEnemy() {
        enemy = SKSpriteNode(color: .red, size: CGSize(width: 40, height: 40))
        enemy.name = "enemy"
        enemy.position = CGPoint(x: size.width / 4, y: -size.height / 6)
        enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)
        enemy.physicsBody?.allowsRotation = false
        enemy.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        addChild(enemy)
    }
    
    func setupControllerSupport() {
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDidConnect), name: .GCControllerDidConnect, object: nil)
        GCController.startWirelessControllerDiscovery()
    }
    
    @objc func controllerDidConnect(notification: Notification) {
        if let controller = notification.object as? GCController {
            setupControllerInputs(controller)
        }
    }
    
    func setupControllerInputs(_ controller: GCController) {
        if let extended = controller.extendedGamepad {
            // Thumbstick for movement and fast-falling
            extended.leftThumbstick.valueChangedHandler = { [weak self] thumbstick, xValue, yValue in
                self?.isMovingLeft = xValue < -0.1
                self?.isMovingRight = xValue > 0.1
                self?.isFastFalling = yValue < -0.5
            }
            
            // Button A: Basic Attack
            extended.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed {
                    self?.performBasicAttack()
                }
            }

            // Button B: Special Attack
            extended.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed {
                    self?.performSpecialAttack()
                }
            }

            // Button L: Shield
            extended.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed {
                    self?.activateShield()
                } else {
                    self?.deactivateShield()
                }
            }

            // Button R: Dodge (with direction)
            extended.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed {
                    let direction = (self?.isMovingRight ?? false) ? 1 : (self?.isMovingLeft ?? false) ? -1 : 0
                    self?.dodge(direction: CGFloat(direction))
                }
            }

            // Button X: Projectile Attack
            extended.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed {
                    self?.performProjectileAttack()
                }
            }

            // Button Y: Jump
            extended.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed {
                    self?.startJump()
                } else {
                    self?.releaseJump()
                }
            }
        }
    }
    
    // Jump variable
    func startJump() {
        if isPlayerOnGround() {
            // Perform the jump immediately
            player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: shortHopImpulse))
            jumpHeld = true
            jumpBufferCounter = 0.0
            jumpQueued = false
        } else {
            // Queue the jump if not grounded
            jumpQueued = true
            jumpBufferCounter = jumpBufferTime
        }
    }

    func continueJump() {
        if jumpHeld && jumpHoldCounter < jumpHoldTime && isPlayerOnGround() {
            player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 20))  // Minor upward boost
            jumpHoldCounter += CGFloat(1.0 / 60.0)  // Increment hold counter
        }
    }

    func releaseJump() {
        jumpHeld = false
        jumpHoldCounter = 0.0
    }
    
    func dodge(direction: CGFloat) {
        player.physicsBody?.applyImpulse(CGVector(dx: direction * 300, dy: 0))
        player.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])) // Visual dodge effect
    }
    
    func activateShield() {
        let shield = SKSpriteNode(color: .cyan, size: CGSize(width: player.size.width + 20, height: player.size.height + 20))
        shield.name = "shield"
        shield.position = player.position
        shield.zPosition = -1
        shield.alpha = 0.5
        addChild(shield)
    }

    func deactivateShield() {
        childNode(withName: "shield")?.removeFromParent()
    }
    
    func performProjectileAttack() {
        let projectile = SKSpriteNode(color: .green, size: CGSize(width: 20, height: 10))
        projectile.position = CGPoint(x: player.position.x + (player.size.width / 2 + 10), y: player.position.y)
        projectile.physicsBody = SKPhysicsBody(rectangleOf: projectile.size)
        projectile.physicsBody?.isDynamic = true
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.attack
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
        projectile.physicsBody?.collisionBitMask = 0
        projectile.physicsBody?.velocity = CGVector(dx: 500, dy: 0) // Move forward
        addChild(projectile)

        projectile.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.removeFromParent()
        ]))
    }
    
    func performSpecialAttack() {
        let specialEffect = SKSpriteNode(color: .orange, size: CGSize(width: 60, height: 60))
        specialEffect.position = player.position
        addChild(specialEffect)

        specialEffect.run(SKAction.sequence([
            SKAction.scale(by: 2.0, duration: 0.3),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))
    }
    
    func performBasicAttack() {
        let attackHitbox = SKSpriteNode(color: .red, size: CGSize(width: 50, height: 20))
        attackHitbox.position = CGPoint(x: player.position.x + (player.size.width / 2 + 25), y: player.position.y)
        attackHitbox.physicsBody = SKPhysicsBody(rectangleOf: attackHitbox.size)
        attackHitbox.physicsBody?.isDynamic = false
        attackHitbox.physicsBody?.categoryBitMask = PhysicsCategory.attack
        attackHitbox.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
        addChild(attackHitbox)

        attackHitbox.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.2),
            SKAction.removeFromParent()
        ]))
    }
    
    
    func isPlayerOnGround() -> Bool {
        guard let physicsBody = player.physicsBody else { return false }
        return physicsBody.velocity.dy == 0
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Handle movement
        if isMovingLeft {
            movePlayer(direction: -1)
        } else if isMovingRight {
            movePlayer(direction: 1)
        } else {
            stopPlayer()
        }

        // Handle fast-falling (only apply when falling)
        if let dy = player.physicsBody?.velocity.dy, dy < 0 && isFastFalling {
            player.physicsBody?.velocity.dy = max(dy, fastFallSpeed)
        }

        // Process jump buffering
        if jumpQueued {
            jumpBufferCounter -= CGFloat(1.0 / 60.0) // Decrease buffer time
            if jumpBufferCounter <= 0 || isPlayerOnGround() {
                player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: shortHopImpulse))
                jumpQueued = false
            }
        }

        for node in children {
            // Ensure the node is an SKSpriteNode and has the correct name
            if let character = node as? SKSpriteNode, character.name == "player" || character.name == "enemy" {
                // Check if the character is outside the blast zone
                if character.position.x < -size.width / 2 - blastZonePadding ||
                   character.position.x > size.width / 2 + blastZonePadding ||
                   character.position.y < -size.height / 2 - blastZonePadding ||
                   character.position.y > size.height / 2 + blastZonePadding {
                    handleBlastZoneExit(for: character)
                }
            }
        }
    }
    
    func movePlayer(direction: CGFloat) {
        horizontalVelocity += direction * acceleration
        horizontalVelocity = max(-maxSpeed, min(maxSpeed, horizontalVelocity)) // Clamp speed
        player.physicsBody?.velocity.dx = horizontalVelocity
    }
    
    func stopPlayer() {
        if horizontalVelocity > 0 {
            horizontalVelocity -= deceleration
        } else if horizontalVelocity < 0 {
            horizontalVelocity += deceleration
        }
        if abs(horizontalVelocity) < deceleration { horizontalVelocity = 0 }
        player.physicsBody?.velocity.dx = horizontalVelocity
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        guard let player = contact.bodyA.node as? SKSpriteNode ?? contact.bodyB.node as? SKSpriteNode else { return }
        guard let edge = contact.bodyA.node?.name == "leftEdge" || contact.bodyB.node?.name == "leftEdge" ? contact.bodyA.node : contact.bodyB.node else { return }

        if player.name == "player" && (edge.name == "leftEdge" || edge.name == "rightEdge") {
            grabEdge(edge: edge)
        }
    }
    
    func grabEdge(edge: SKNode) {
        guard let player = player else { return }

        // Ensure the player is falling and below the platform height
        if let velocity = player.physicsBody?.velocity.dy, velocity >= 0 {
            return // Ignore edge-grabbing if not falling
        }
        
        // Ensure the player is near the edge but below the top of the platform
        if abs(player.position.y - edge.position.y) > player.size.height {
            return // Ignore if the player is too high above the edge
        }

        // Position player on the edge
        let edgeX = edge.position.x
        let edgeY = edge.position.y
        player.physicsBody?.velocity = .zero
        player.position = CGPoint(x: edgeX, y: edgeY + player.size.height / 2)

        // Add a delay to prevent immediate re-grabbing
        player.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run { self.player.physicsBody?.velocity = .zero }
        ]))
    }

    func handleBlastZoneExit(for character: SKSpriteNode) {
        // Attempt to load the explosion effect
        if let explosion = SKEmitterNode(fileNamed: "Explosion.sks") {
            explosion.position = character.position
            addChild(explosion)
            
            // Remove the explosion after 1 second
            explosion.run(SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.removeFromParent()
            ]))
        } else {
            print("Error: Explosion.sks file not found or failed to load.")
        }

        // Remove character from scene temporarily
        character.removeFromParent()

        // Respawn character after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.respawnCharacter(character)
        }
    }
    
    func respawnCharacter(_ character: SKSpriteNode) {
        // Re-add the character to the scene
        if character.parent == nil {
            addChild(character)
        }

        // Set a respawn position
        if character.name == "player" {
            character.position = CGPoint(x: 0, y: size.height / 4) // Adjust player respawn point
        } else if character.name == "enemy" {
            character.position = CGPoint(x: 100, y: size.height / 4) // Adjust enemy respawn point
        }

        // Reset physics
        character.physicsBody?.velocity = .zero
        character.physicsBody?.angularVelocity = 0
    }
}