import SpriteKit
import UIKit

private enum Ink {
    static let sky = SKColor(hex: 0x081221)
    static let blue = SKColor(hex: 0x162D40)
    static let white = SKColor(hex: 0xF4F2DB)
    static let muted = SKColor(hex: 0x879BA4)
    static let aqua = SKColor(hex: 0x6AE6DE)
    static let orange = SKColor(hex: 0xFFC078)
    static let red = SKColor(hex: 0xF5786D)
    static let green = SKColor(hex: 0x8DE8A6)
}
private extension SKColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 255) / 255,
                  green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

private struct Hostile {
    let sprite: SKSpriteNode
    var hitPoints: Int
    let maximum: Int
    let kind: Int
    var age: CGFloat
    var nextShot: CGFloat
    var speed: CGFloat
}
private struct Projectile {
    let sprite: SKSpriteNode
    let playerOwned: Bool
    let damage: Int
    let velocity: CGVector
}
private struct Supply {
    let sprite: SKSpriteNode
    let kind: Int
    var age: CGFloat
}
private struct SkyPoint {
    let node: SKShapeNode
    let speed: CGFloat
}

final class AstraScene: SKScene {
    private enum Mode { case menu, playing, paused, gameOver }
    private var mode: Mode = .menu

    private let backdrop = SKNode()
    private let field = SKNode()
    private let effects = SKNode()
    private let hud = SKNode()
    private var menuLayer = SKNode()

    private var stars: [SkyPoint] = []
    private var enemies: [Hostile] = []
    private var projectiles: [Projectile] = []
    private var supplies: [Supply] = []
    private var ship: SKSpriteNode?
    private var core: SKShapeNode?

    private var lastUpdate: TimeInterval = 0
    private var totalTime: CGFloat = 0
    private var spawnClock: CGFloat = 0
    private var fireClock: CGFloat = 0
    private var nextBossAt: CGFloat = 52
    private var bossActive = false
    private var score = 0
    private var highScore = UserDefaults.standard.integer(forKey: "astra.best")
    private var kills = 0
    private var combo = 0
    private var comboRemaining: CGFloat = 0
    private var health = 3
    private var shield = 0
    private var bombs = 1
    private var weapon = 1
    private var invulnerable: CGFloat = 0
    private var targetPosition: CGPoint?
    private var fingerActive = false
    private var sector = 1
    private var screenFlash: SKShapeNode?

    private var pointsLabel: SKLabelNode?
    private var livesLabel: SKLabelNode?
    private var sectorLabel: SKLabelNode?
    private var multiplierLabel: SKLabelNode?
    private var bombLabel: SKLabelNode?
    private var bossHealthFill: SKShapeNode?
    private var bossHealthBack: SKShapeNode?
    private var alertNode: SKNode?

    override func didMove(to view: SKView) {
        backgroundColor = Ink.sky
        anchorPoint = .zero
        addChild(backdrop)
        addChild(field)
        addChild(effects)
        addChild(hud)
        populateBackdrop()
        showMenu()
        AstraAudio.shared.startMusic()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if view != nil {
            populateBackdrop()
            switch mode {
            case .menu: showMenu()
            case .playing, .paused: buildHUD()
            case .gameOver: showGameOver()
            }
        }
    }

    private func texture(_ name: String) -> SKTexture {
        let value = SKTexture(imageNamed: name)
        value.filteringMode = .nearest
        return value
    }

    private func sprite(_ name: String, width: CGFloat, height: CGFloat, at point: CGPoint) -> SKSpriteNode {
        let item = SKSpriteNode(texture: texture(name), size: CGSize(width: width, height: height))
        item.position = point
        return item
    }

    @discardableResult
    private func text(_ string: String, size: CGFloat, at point: CGPoint, color: SKColor = Ink.white,
                      align: SKLabelHorizontalAlignmentMode = .center, parent: SKNode? = nil,
                      heavy: Bool = false) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: heavy ? "AvenirNextCondensed-Heavy" : "Menlo-Bold")
        node.text = string
        node.fontSize = size
        node.fontColor = color
        node.horizontalAlignmentMode = align
        node.verticalAlignmentMode = .center
        node.position = point
        (parent ?? hud).addChild(node)
        return node
    }

    private func line(from a: CGPoint, to b: CGPoint, color: SKColor, alpha: CGFloat = 1, width: CGFloat = 1,
                      parent: SKNode? = nil) {
        let path = CGMutablePath()
        path.move(to: a)
        path.addLine(to: b)
        let n = SKShapeNode(path: path)
        n.lineWidth = width
        n.strokeColor = color
        n.alpha = alpha
        n.isAntialiased = false
        (parent ?? backdrop).addChild(n)
    }

    private func populateBackdrop() {
        backdrop.removeAllChildren()
        stars.removeAll()
        // Crisp analog scrolling field, two-depth celestial parallax.
        let w = size.width, h = size.height
        let haze = SKShapeNode(rect: CGRect(x: 0, y: h * 0.58, width: w, height: h * 0.42))
        haze.fillColor = SKColor(hex: 0x0D1D2C)
        haze.strokeColor = .clear
        backdrop.addChild(haze)
        for index in 0..<58 {
            let seed = (index * 1877 + 367) % 10007
            let px = CGFloat((seed * 101 + 73) % 1000) / 1000 * w
            let py = CGFloat((seed * 311 + 41) % 1000) / 1000 * h
            let far = index % 3 == 0
            let mark = SKShapeNode(rectOf: CGSize(width: far ? 2 : 1, height: far ? 5 : 2))
            mark.fillColor = far ? Ink.aqua : Ink.muted
            mark.strokeColor = .clear
            mark.alpha = far ? 0.58 : 0.35
            mark.position = CGPoint(x: px, y: py)
            backdrop.addChild(mark)
            stars.append(SkyPoint(node: mark, speed: far ? 115 : 45))
        }
        for i in 0..<11 {
            let stripe = SKShapeNode(rectOf: CGSize(width: w * 1.3, height: 1))
            stripe.fillColor = Ink.aqua.withAlphaComponent(0.042)
            stripe.strokeColor = .clear
            stripe.position = CGPoint(x: w / 2, y: CGFloat(i) * h / 11)
            backdrop.addChild(stripe)
        }
        line(from: CGPoint(x: 0, y: 5), to: CGPoint(x: w, y: 5), color: Ink.aqua, alpha: 0.28)
    }

    private func updateBackdrop(_ dt: CGFloat) {
        for star in stars {
            star.node.position.y -= star.speed * dt
            if star.node.position.y < -8 {
                star.node.position.y = size.height + 8
            }
        }
    }

    private func button(_ title: String, name: String, at center: CGPoint, width: CGFloat,
                        highlighted: Bool = false, parent: SKNode? = nil) {
        let container = SKNode()
        container.name = "button." + name
        container.position = center
        let panel = SKShapeNode(rectOf: CGSize(width: width, height: 56), cornerRadius: 5)
        panel.fillColor = highlighted ? Ink.aqua : Ink.blue
        panel.strokeColor = highlighted ? Ink.aqua : Ink.muted.withAlphaComponent(0.5)
        panel.lineWidth = 1.5
        panel.name = container.name
        container.addChild(panel)
        let label = text(title, size: 17, at: CGPoint(x: 0, y: 1),
                         color: highlighted ? Ink.sky : Ink.white,
                         parent: container)
        label.name = container.name
        (parent ?? hud).addChild(container)
    }

    private func showMenu() {
        mode = .menu
        field.removeAllChildren()
        effects.removeAllChildren()
        hud.removeAllChildren()
        projectiles.removeAll()
        enemies.removeAll()
        supplies.removeAll()
        ship = nil
        menuLayer = SKNode()
        hud.addChild(menuLayer)
        let w = size.width, h = size.height
        let top = h * 0.80

        text("SIGNAL / 024", size: 11, at: CGPoint(x: 26, y: h - 76), color: Ink.aqua, align: .left, parent: menuLayer)
        text("ARCADE DIVISION", size: 11, at: CGPoint(x: w - 25, y: h - 76), color: Ink.muted, align: .right, parent: menuLayer)
        line(from: CGPoint(x: 26, y: h - 99), to: CGPoint(x: w - 26, y: h - 99),
             color: Ink.aqua, alpha: 0.35, parent: menuLayer)

        text("A S T R A", size: min(74, w * 0.18), at: CGPoint(x: w / 2, y: top),
             color: Ink.white, parent: menuLayer, heavy: true)
        text("LAST LIGHT SQUADRON", size: 13, at: CGPoint(x: w / 2, y: top - 47),
             color: Ink.aqua, parent: menuLayer)

        let craft = sprite("falcon.png", width: 175, height: 215, at: CGPoint(x: w / 2, y: h * 0.49))
        menuLayer.addChild(craft)
        craft.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 9, duration: 1.35),
            SKAction.moveBy(x: 0, y: -9, duration: 1.35)
        ])))
        let ellipse = SKShapeNode(ellipseOf: CGSize(width: 235, height: 112))
        ellipse.position = craft.position
        ellipse.strokeColor = Ink.aqua.withAlphaComponent(0.15)
        ellipse.lineWidth = 1
        menuLayer.insertChild(ellipse, at: 0)

        let by = h * 0.305
        text("ONE PILOT. ENDLESS SKY.", size: 14, at: CGPoint(x: w / 2, y: by + 80),
             color: Ink.white, parent: menuLayer)
        button("DEPLOY  /  START", name: "play", at: CGPoint(x: w / 2, y: by),
               width: min(w - 82, 344), highlighted: true, parent: menuLayer)
        text("DRAG TO FLY    •    AUTO-FIRE", size: 11, at: CGPoint(x: w / 2, y: by - 65),
             color: Ink.muted, parent: menuLayer)

        text("BEST    " + formatted(highScore), size: 13, at: CGPoint(x: w / 2, y: 115),
             color: Ink.orange, parent: menuLayer)
        button(AstraAudio.shared.isSoundOn ? "SOUND  ON" : "SOUND  OFF", name: "sound",
               at: CGPoint(x: w * 0.29, y: 58), width: 130, parent: menuLayer)
        button(AstraAudio.shared.isHapticsOn ? "HAPTICS ON" : "HAPTICS OFF", name: "haptics",
               at: CGPoint(x: w * 0.71, y: 58), width: 130, parent: menuLayer)
    }

    private func beginMission() {
        mode = .playing
        hud.removeAllChildren()
        field.removeAllChildren()
        effects.removeAllChildren()
        enemies.removeAll()
        projectiles.removeAll()
        supplies.removeAll()
        score = 0; kills = 0; combo = 0; comboRemaining = 0
        health = 3; shield = 0; bombs = 1; weapon = 1
        totalTime = 0; spawnClock = 0.5; fireClock = 0; nextBossAt = 52
        invulnerable = 1.8; bossActive = false; sector = 1
        fingerActive = false; targetPosition = nil
        let craft = sprite("falcon.png", width: 59, height: 74,
                           at: CGPoint(x: size.width / 2, y: max(165, size.height * 0.22)))
        craft.zPosition = 20
        field.addChild(craft)
        ship = craft

        // A small honest collision core, separate from the decorative wing silhouette.
        let center = SKShapeNode(circleOfRadius: 3)
        center.fillColor = Ink.aqua
        center.strokeColor = Ink.white
        center.lineWidth = 1
        center.zPosition = 2
        craft.addChild(center)
        core = center

        buildHUD()
        announce("SECTOR 01  /  DEPARTURE", color: Ink.aqua)
        AstraAudio.shared.play("click")
    }

    private func buildHUD() {
        hud.removeAllChildren()
        let w = size.width, h = size.height
        line(from: CGPoint(x: 19, y: h - 137), to: CGPoint(x: w - 19, y: h - 137),
             color: Ink.aqua, alpha: 0.32, parent: hud)
        text("S C O R E", size: 10, at: CGPoint(x: 22, y: h - 77), color: Ink.muted,
             align: .left)
        pointsLabel = text(formatted(score), size: 22, at: CGPoint(x: 22, y: h - 103),
                           align: .left, heavy: true)
        sectorLabel = text("SECTOR 0\(sector)", size: 12, at: CGPoint(x: w / 2, y: h - 111),
                            color: Ink.aqua)
        livesLabel = text("◆ ◆ ◆", size: 16, at: CGPoint(x: w - 77, y: h - 105),
                          color: Ink.orange, align: .right)
        let pause = text("Ⅱ", size: 27, at: CGPoint(x: w - 35, y: h - 103),
                         color: Ink.white)
        pause.name = "button.pause"
        multiplierLabel = text("", size: 11, at: CGPoint(x: w / 2, y: h - 86),
                                color: Ink.orange)

        let bomb = SKShapeNode(rectOf: CGSize(width: 83, height: 58), cornerRadius: 5)
        bomb.name = "button.bomb"
        bomb.position = CGPoint(x: w - 62, y: 95)
        bomb.fillColor = Ink.blue
        bomb.strokeColor = Ink.orange
        bomb.lineWidth = 1
        hud.addChild(bomb)
        let bombText = text("BOMB", size: 11, at: CGPoint(x: w - 62, y: 105),
                            color: Ink.orange)
        bombText.name = "button.bomb"
        bombLabel = text("×  \(bombs)", size: 17, at: CGPoint(x: w - 62, y: 83),
                         color: Ink.white)
        bombLabel?.name = "button.bomb"
        text("DRAG TO FLY", size: 10, at: CGPoint(x: 26, y: 65),
             color: Ink.muted, align: .left)
        syncHUD()
    }

    private func syncHUD() {
        pointsLabel?.text = formatted(score)
        sectorLabel?.text = String(format: "SECTOR %02d", sector)
        var glyphs = String(repeating: "◆ ", count: max(0, health))
        if shield > 0 { glyphs += "◈\(shield)" }
        livesLabel?.text = glyphs.trimmingCharacters(in: .whitespaces)
        bombLabel?.text = "×  \(bombs)"
        multiplierLabel?.text = combo >= 4 ? "CHAIN  ×\(min(5, 1 + combo / 5))" : ""
    }

    private func formatted(_ count: Int) -> String {
        String(format: "%07d", count)
    }

    private func announce(_ message: String, color: SKColor) {
        alertNode?.removeFromParent()
        let holder = SKNode()
        alertNode = holder
        holder.alpha = 0
        holder.position = CGPoint(x: size.width / 2, y: size.height * 0.67)
        let back = SKShapeNode(rectOf: CGSize(width: min(size.width - 40, 370), height: 46), cornerRadius: 3)
        back.fillColor = Ink.sky.withAlphaComponent(0.89)
        back.strokeColor = color.withAlphaComponent(0.65)
        back.lineWidth = 1
        holder.addChild(back)
        text(message, size: 13, at: .zero, color: color, parent: holder)
        hud.addChild(holder)
        holder.run(.sequence([.fadeIn(withDuration: 0.16), .wait(forDuration: 1.2),
                              .fadeOut(withDuration: 0.44), .removeFromParent()]))
    }

    private func displayPause() {
        guard mode == .playing else { return }
        mode = .paused
        let group = SKNode()
        group.name = "pauseOverlay"
        group.zPosition = 1000
        hud.addChild(group)
        let shade = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        shade.fillColor = Ink.sky.withAlphaComponent(0.92)
        shade.strokeColor = .clear
        group.addChild(shade)
        text("SYSTEM / PAUSED", size: 12, at: CGPoint(x: size.width / 2, y: size.height * 0.68),
             color: Ink.aqua, parent: group)
        text("HOLD POSITION", size: 41, at: CGPoint(x: size.width / 2, y: size.height * 0.57),
             parent: group, heavy: true)
        button("RESUME FLIGHT", name: "resume", at: CGPoint(x: size.width / 2, y: size.height * 0.43),
               width: min(size.width - 70, 330), highlighted: true, parent: group)
        button("ABORT MISSION", name: "quit", at: CGPoint(x: size.width / 2, y: size.height * 0.34),
               width: min(size.width - 70, 330), parent: group)
        text("AUTO-FIRE ENABLED", size: 11, at: CGPoint(x: size.width / 2, y: size.height * 0.23),
             color: Ink.muted, parent: group)
    }

    private func resumeMission() {
        hud.childNode(withName: "pauseOverlay")?.removeFromParent()
        mode = .playing
        fingerActive = false
        targetPosition = nil
        lastUpdate = 0
        AstraAudio.shared.play("click")
    }

    private func showGameOver() {
        mode = .gameOver
        field.removeAllChildren()
        effects.removeAllChildren()
        hud.removeAllChildren()
        let w = size.width, h = size.height
        text("MISSION / TERMINATED", size: 12, at: CGPoint(x: w / 2, y: h * 0.78),
             color: Ink.red)
        text("SIGNAL LOST", size: 53, at: CGPoint(x: w / 2, y: h * 0.67),
             color: Ink.white, heavy: true)
        line(from: CGPoint(x: 40, y: h * 0.61), to: CGPoint(x: w - 40, y: h * 0.61),
             color: Ink.red, alpha: 0.55, parent: hud)
        text("FINAL SCORE", size: 12, at: CGPoint(x: w / 2, y: h * 0.55),
             color: Ink.muted)
        text(formatted(score), size: 46, at: CGPoint(x: w / 2, y: h * 0.49),
             color: Ink.orange, heavy: true)
        text("BEST   " + formatted(highScore), size: 13, at: CGPoint(x: w / 2, y: h * 0.41),
             color: Ink.aqua)
        button("REDEPLOY", name: "retry", at: CGPoint(x: w / 2, y: h * 0.29),
               width: min(w - 75, 320), highlighted: true)
        button("MAIN HANGAR", name: "home", at: CGPoint(x: w / 2, y: h * 0.19),
               width: min(w - 75, 320))
        text("PILOTS FALL. LEGENDS RETURN.", size: 10, at: CGPoint(x: w / 2, y: 65),
             color: Ink.muted)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? CGFloat(1.0 / 60.0) : min(0.04, max(0, CGFloat(currentTime - lastUpdate)))
        lastUpdate = currentTime
        if mode == .paused { return }
        updateBackdrop(dt)
        guard mode == .playing, let craft = ship else { return }
        totalTime += dt
        invulnerable = max(0, invulnerable - dt)
        comboRemaining -= dt
        if comboRemaining <= 0 { combo = 0 }
        craft.alpha = invulnerable > 0 && Int(totalTime * 14) % 2 == 0 ? 0.48 : 1
        if let desired = targetPosition {
            let blend = min(1, dt * 19)
            craft.position.x += (desired.x - craft.position.x) * blend
            craft.position.y += (desired.y - craft.position.y) * blend
        }
        fireClock -= dt
        if fireClock <= 0 {
            firePlayer()
            fireClock = weapon >= 3 ? 0.103 : 0.148
        }
        let newSector = min(99, 1 + Int(totalTime / 35))
        if newSector > sector {
            sector = newSector
            announce(String(format: "SECTOR %02d  /  THREAT RISING", sector), color: Ink.aqua)
        }
        if totalTime >= nextBossAt && !bossActive {
            summonBoss()
        }

        if !bossActive {
            spawnClock -= dt
            if spawnClock <= 0 {
                spawnFormation()
                spawnClock = max(0.48, 1.12 - CGFloat(sector - 1) * 0.045)
            }
        }
        updateHostiles(dt)
        updateProjectiles(dt)
        updateSupplies(dt)
        detectRamming()
        syncHUD()
    }

    private func firePlayer() {
        guard let craft = ship else { return }
        let p = craft.position
        let barrelY = p.y + 34
        let offsets: [(CGFloat, CGFloat, CGFloat)]
        if weapon == 1 {
            offsets = [(0, 0, 0)]
        } else if weapon == 2 {
            offsets = [(-13, -32, 0), (13, 32, 0)]
        } else {
            offsets = [(-17, -122, 0), (0, 0, 0), (17, 122, 0)]
        }
        for (x, vx, _) in offsets {
            let bullet = sprite("laser.png", width: 9, height: 29,
                                at: CGPoint(x: p.x + x, y: barrelY))
            bullet.zPosition = 8
            field.addChild(bullet)
            projectiles.append(Projectile(sprite: bullet, playerOwned: true, damage: weapon >= 3 ? 12 : 10,
                                           velocity: CGVector(dx: vx, dy: 760)))
        }
        if Int(totalTime * 10) % 3 == 0 { AstraAudio.shared.play("shoot") }
        if Int(totalTime * 100) % 8 == 0 {
            spark(at: CGPoint(x: p.x, y: p.y - 32), color: Ink.orange, count: 2, scale: 0.36)
        }
    }

    private func spawnFormation() {
        let available = max(55, size.width - 110)
        let enemyKind: Int
        let roll = Int.random(in: 0..<100)
        if sector >= 3 && roll < 14 { enemyKind = 2 }
        else if sector >= 2 && roll < 37 { enemyKind = 1 }
        else { enemyKind = 0 }
        let x = CGFloat.random(in: 55...(55 + available))
        spawnEnemy(kind: enemyKind, x: min(size.width - 40, x), y: size.height + 48)
        if sector > 1 && Int.random(in: 0..<100) < 24 {
            let spread: CGFloat = Bool.random() ? 67 : -67
            spawnEnemy(kind: 0, x: max(42, min(size.width - 42, x + spread)),
                       y: size.height + 122)
        }
    }

    private func spawnEnemy(kind: Int, x: CGFloat, y: CGFloat) {
        let name = kind == 0 ? "enemy_scout.png" : kind == 1 ? "enemy_ace.png" : "enemy_heavy.png"
        let width: CGFloat = kind == 2 ? 70 : 49
        let height: CGFloat = kind == 2 ? 61 : 60
        let enemy = sprite(name, width: width, height: height, at: CGPoint(x: x, y: y))
        enemy.zPosition = 14
        field.addChild(enemy)
        let hp = kind == 2 ? 54 : kind == 1 ? 31 : 18
        enemies.append(Hostile(sprite: enemy, hitPoints: hp + (sector - 1) * 3,
                               maximum: hp + (sector - 1) * 3, kind: kind, age: 0,
                               nextShot: CGFloat.random(in: 1.1...2.3),
                               speed: (kind == 2 ? 75 : kind == 1 ? 148 : 115) + CGFloat(sector - 1) * 5))
    }

    private func summonBoss() {
        bossActive = true
        spawnClock = 2.0
        AstraAudio.shared.play("warning")
        AstraAudio.shared.impact(.heavy)
        announce("WARNING  /  DREADNOUGHT INBOUND", color: Ink.red)
        let boss = sprite("boss.png", width: min(size.width - 42, 312), height: 222,
                          at: CGPoint(x: size.width / 2, y: size.height + 140))
        boss.zPosition = 17
        field.addChild(boss)
        let hp = 300 + (sector - 1) * 70
        enemies.append(Hostile(sprite: boss, hitPoints: hp, maximum: hp, kind: 3,
                               age: 0, nextShot: 2.4, speed: 60))
        let width = min(size.width * 0.65, 260)
        let base = SKShapeNode(rect: CGRect(x: 0, y: 0, width: width, height: 7))
        base.position = CGPoint(x: (size.width - width) / 2, y: size.height - 167)
        base.fillColor = Ink.blue
        base.strokeColor = Ink.muted
        base.lineWidth = 1
        hud.addChild(base)
        bossHealthBack = base
        let fill = SKShapeNode(rect: CGRect(x: 0, y: 0, width: width, height: 7))
        fill.position = base.position
        fill.fillColor = Ink.red
        fill.strokeColor = .clear
        hud.addChild(fill)
        bossHealthFill = fill
    }

    private func updateHostiles(_ dt: CGFloat) {
        guard let craft = ship else { return }
        for i in enemies.indices.reversed() {
            enemies[i].age += dt
            enemies[i].nextShot -= dt
            let enemy = enemies[i]
            if enemy.kind == 3 {
                let destination = size.height * 0.79
                if enemy.sprite.position.y > destination {
                    enemy.sprite.position.y = max(destination, enemy.sprite.position.y - dt * 130)
                } else {
                    enemy.sprite.position.x = size.width / 2 + sin(enemy.age * 0.82) * size.width * 0.19
                }
            } else {
                enemy.sprite.position.y -= enemy.speed * dt
                if enemy.kind == 1 {
                    enemy.sprite.position.x += cos(enemy.age * 3.2) * 105 * dt
                    enemy.sprite.position.x = min(size.width - 30, max(30, enemy.sprite.position.x))
                }
            }
            if enemies[i].nextShot <= 0 && enemy.sprite.position.y < size.height - 125 {
                fireHostile(enemy, at: craft.position)
                enemies[i].nextShot = enemy.kind == 3 ? 1.28 : enemy.kind == 2 ? 1.8 : enemy.kind == 1 ? 1.57 : 2.5
            }
            if enemy.sprite.position.y < -100 {
                enemy.sprite.removeFromParent()
                enemies.remove(at: i)
            }
        }
    }

    private func fireHostile(_ enemy: Hostile, at target: CGPoint) {
        let origin = enemy.sprite.position
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let norm = max(1, hypot(dx, dy))
        let vx = dx / norm
        let vy = dy / norm
        if enemy.kind == 3 {
            for offset in -3...3 {
                let direction = CGFloat(offset) * 0.17
                let speed: CGFloat = 225
                let delta = CGVector(dx: sin(direction) * speed, dy: -cos(direction) * speed)
                launchEnemyShot(at: CGPoint(x: origin.x + CGFloat(offset) * 9,
                                            y: origin.y - 96), velocity: delta, large: true)
            }
            // Slowly aimed cannon rounds force a positional decision, not random unavoidable rain.
            if Int(enemy.age) % 3 == 0 {
                launchEnemyShot(at: CGPoint(x: origin.x, y: origin.y - 90),
                                velocity: CGVector(dx: vx * 275, dy: vy * 275), large: true)
            }
        } else if enemy.kind == 2 {
            for offset in [-0.15, 0.15] {
                let v = CGVector(dx: vx * 205 + CGFloat(offset) * 160, dy: vy * 205)
                launchEnemyShot(at: CGPoint(x: origin.x + CGFloat(offset) * 100,
                                            y: origin.y - 23), velocity: v)
            }
        } else {
            launchEnemyShot(at: CGPoint(x: origin.x, y: origin.y - 26),
                            velocity: CGVector(dx: vx * 245, dy: vy * 245))
        }
    }

    private func launchEnemyShot(at p: CGPoint, velocity: CGVector, large: Bool = false) {
        let projectile = sprite(large ? "boss_laser.png" : "enemy_laser.png",
                                width: large ? 12 : 10, height: large ? 32 : 26, at: p)
        projectile.zPosition = 12
        projectile.zRotation = atan2(velocity.dy, velocity.dx) - .pi / 2
        field.addChild(projectile)
        projectiles.append(Projectile(sprite: projectile, playerOwned: false,
                                       damage: 1, velocity: velocity))
    }

    private func updateProjectiles(_ dt: CGFloat) {
        for i in projectiles.indices.reversed() {
            let shot = projectiles[i]
            shot.sprite.position.x += shot.velocity.dx * dt
            shot.sprite.position.y += shot.velocity.dy * dt
            let p = shot.sprite.position
            var remove = p.y < -40 || p.y > size.height + 80 || p.x < -40 || p.x > size.width + 40
            if !remove && shot.playerOwned {
                for j in enemies.indices.reversed() {
                    let enemy = enemies[j]
                    let radius: CGFloat = enemy.kind == 3 ? 105 : enemy.kind == 2 ? 30 : 22
                    let x = (p.x - enemy.sprite.position.x) / (radius * (enemy.kind == 3 ? 1.15 : 1))
                    let y = (p.y - enemy.sprite.position.y) / (radius * (enemy.kind == 3 ? 0.75 : 1))
                    if x * x + y * y < 1 {
                        hurtEnemy(at: j, by: shot.damage)
                        remove = true
                        break
                    }
                }
            } else if !remove && !shot.playerOwned, let craft = ship, invulnerable <= 0 {
                if hypot(p.x - craft.position.x, p.y - craft.position.y) < 17 {
                    loseHealth()
                    remove = true
                }
            }
            if remove {
                shot.sprite.removeFromParent()
                projectiles.remove(at: i)
            }
        }
    }

    private func hurtEnemy(at index: Int, by damage: Int) {
        guard enemies.indices.contains(index) else { return }
        enemies[index].hitPoints -= damage
        let enemy = enemies[index]
        if enemy.kind == 3 {
            bossHealthFill?.xScale = max(0, CGFloat(enemy.hitPoints) / CGFloat(enemy.maximum))
        }
        if enemy.hitPoints <= 0 {
            destroyEnemy(at: index)
        } else if Int.random(in: 0..<5) == 0 {
            spark(at: CGPoint(x: enemy.sprite.position.x + CGFloat.random(in: -12...12),
                              y: enemy.sprite.position.y + CGFloat.random(in: -12...12)),
                  color: Ink.orange, count: 2, scale: 0.45)
        }
    }

    private func destroyEnemy(at index: Int) {
        let enemy = enemies.remove(at: index)
        let location = enemy.sprite.position
        let boss = enemy.kind == 3
        enemy.sprite.removeFromParent()
        spark(at: location, color: boss ? Ink.orange : Ink.red,
              count: boss ? 48 : 17, scale: boss ? 2 : 0.8)
        AstraAudio.shared.play("explode")
        if boss { AstraAudio.shared.impact(.heavy) }
        let chain = min(5, 1 + combo / 5)
        let value = boss ? 7000 : enemy.kind == 2 ? 420 : enemy.kind == 1 ? 225 : 120
        score += value * chain
        kills += 1
        combo += 1
        comboRemaining = 2.8
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "astra.best")
        }
        if boss {
            bossActive = false
            nextBossAt = totalTime + 73
            bossHealthBack?.removeFromParent()
            bossHealthFill?.removeFromParent()
            bossHealthBack = nil
            bossHealthFill = nil
            bombs = min(3, bombs + 1)
            health = min(3, health + 1)
            for shot in projectiles where !shot.playerOwned { shot.sprite.removeFromParent() }
            projectiles.removeAll(where: { !$0.playerOwned })
            announce("TARGET DESTROYED  /  +7000", color: Ink.aqua)
            spawnSupply(kind: 0, at: CGPoint(x: size.width / 2, y: size.height * 0.57))
        } else if kills % 12 == 0 {
            spawnSupply(kind: [0, 0, 1, 2, 3].randomElement() ?? 0, at: location)
        }
    }

    private func detectRamming() {
        guard let craft = ship, invulnerable <= 0 else { return }
        for i in enemies.indices.reversed() {
            if enemies[i].kind == 3 { continue }
            if hypot(enemies[i].sprite.position.x - craft.position.x,
                     enemies[i].sprite.position.y - craft.position.y) < 29 {
                destroyEnemy(at: i)
                loseHealth()
                break
            }
        }
    }

    private func loseHealth() {
        guard invulnerable <= 0, mode == .playing else { return }
        if shield > 0 { shield -= 1 }
        else { health -= 1 }
        invulnerable = 1.65
        if let craft = ship {
            spark(at: craft.position, color: Ink.orange, count: 17, scale: 1)
        }
        AstraAudio.shared.play("hit")
        AstraAudio.shared.impact(.medium)
        let shade = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        shade.fillColor = Ink.red
        shade.strokeColor = .clear
        shade.alpha = 0.19
        shade.zPosition = 400
        effects.addChild(shade)
        shade.run(.sequence([.fadeOut(withDuration: 0.24), .removeFromParent()]))
        if health <= 0 {
            AstraAudio.shared.play("explode")
            showGameOver()
        }
    }

    private func spawnSupply(kind: Int, at point: CGPoint) {
        let image = ["pickup_power.png", "pickup_repair.png", "pickup_bomb.png", "pickup_shield.png"][kind]
        let s = sprite(image, width: 39, height: 39, at: point)
        s.zPosition = 15
        field.addChild(s)
        supplies.append(Supply(sprite: s, kind: kind, age: 0))
    }

    private func updateSupplies(_ dt: CGFloat) {
        for i in supplies.indices.reversed() {
            supplies[i].age += dt
            let supply = supplies[i]
            supply.sprite.position.y -= 78 * dt
            supply.sprite.zRotation += 1.3 * dt
            if let craft = ship, hypot(supply.sprite.position.x - craft.position.x,
                                       supply.sprite.position.y - craft.position.y) < 39 {
                switch supply.kind {
                case 0: weapon = min(3, weapon + 1); announce("ARMAMENT  /  UPGRADED", color: Ink.aqua)
                case 1: health = min(3, health + 1); announce("HULL  /  REPAIRED", color: Ink.green)
                case 2: bombs = min(3, bombs + 1); announce("ORDNANCE  /  RESTORED", color: Ink.orange)
                default: shield = min(2, shield + 1); announce("AEGIS  /  SHIELD ONLINE", color: Ink.aqua)
                }
                spark(at: supply.sprite.position, color: Ink.aqua, count: 16, scale: 0.8)
                AstraAudio.shared.play("pickup")
                AstraAudio.shared.impact(.light)
                supply.sprite.removeFromParent()
                supplies.remove(at: i)
            } else if supply.sprite.position.y < -40 {
                supply.sprite.removeFromParent()
                supplies.remove(at: i)
            }
        }
    }

    private func useBomb() {
        guard mode == .playing, bombs > 0 else { return }
        bombs -= 1
        AstraAudio.shared.play("bomb")
        AstraAudio.shared.impact(.heavy)
        let ring = SKShapeNode(circleOfRadius: 45)
        ring.position = ship?.position ?? CGPoint(x: size.width / 2, y: size.height / 2)
        ring.strokeColor = Ink.aqua
        ring.lineWidth = 7
        ring.fillColor = Ink.aqua.withAlphaComponent(0.06)
        ring.zPosition = 200
        effects.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 13, duration: 0.65),
                                    .fadeOut(withDuration: 0.65)]), .removeFromParent()]))
        for shot in projectiles where !shot.playerOwned { shot.sprite.removeFromParent() }
        projectiles.removeAll(where: { !$0.playerOwned })
        for i in enemies.indices.reversed() {
            let damage = enemies[i].kind == 3 ? 105 : 999
            hurtEnemy(at: i, by: damage)
        }
        invulnerable = max(invulnerable, 0.75)
        syncHUD()
    }

    private func spark(at point: CGPoint, color: SKColor, count: Int, scale: CGFloat) {
        for _ in 0..<count {
            let chip = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 2...5) * scale,
                                                   height: CGFloat.random(in: 3...9) * scale))
            chip.fillColor = Int.random(in: 0..<4) == 0 ? Ink.white : color
            chip.strokeColor = .clear
            chip.isAntialiased = false
            chip.position = point
            chip.zPosition = 150
            effects.addChild(chip)
            let dx = CGFloat.random(in: -98...98) * scale
            let dy = CGFloat.random(in: -130...130) * scale
            let duration = Double.random(in: 0.25...0.70)
            chip.run(.sequence([.group([.moveBy(x: dx, y: dy, duration: duration),
                                         .fadeOut(withDuration: duration),
                                         .rotate(byAngle: CGFloat.random(in: -3...3), duration: duration)]),
                                .removeFromParent()]))
        }
    }

    private func chosenButton(at p: CGPoint) -> String? {
        for hit in nodes(at: p) {
            var candidate: SKNode? = hit
            for _ in 0..<3 {
                if let name = candidate?.name, name.hasPrefix("button.") {
                    return String(name.dropFirst("button.".count))
                }
                candidate = candidate?.parent
            }
        }
        return nil
    }

    private func aim(for point: CGPoint) -> CGPoint {
        let margin: CGFloat = 34
        return CGPoint(x: min(size.width - margin, max(margin, point.x)),
                       y: min(size.height * 0.68, max(size.height * 0.16, point.y + 68)))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        if let choice = chosenButton(at: p) {
            switch choice {
            case "play", "retry": beginMission()
            case "home", "quit": showMenu()
            case "pause": displayPause()
            case "resume": resumeMission()
            case "bomb": useBomb()
            case "sound": _ = AstraAudio.shared.toggleSound(); showMenu()
            case "haptics": _ = AstraAudio.shared.toggleHaptics(); showMenu()
            default: break
            }
            if choice != "bomb" { AstraAudio.shared.play("click") }
            return
        }
        if mode == .playing {
            fingerActive = true
            targetPosition = aim(for: p)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard mode == .playing, fingerActive, let touch = touches.first else { return }
        targetPosition = aim(for: touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        fingerActive = false
        targetPosition = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        fingerActive = false
        targetPosition = nil
    }
}
