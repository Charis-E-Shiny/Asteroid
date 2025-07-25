import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

void main() {
  runApp(const AsteroidsApp());
}

class AsteroidsApp extends StatelessWidget {
  const AsteroidsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asteroids Game',
      theme: ThemeData.dark(),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Vector2 {
  double x, y;
  Vector2(this.x, this.y);
  
  Vector2 operator +(Vector2 other) => Vector2(x + other.x, y + other.y);
  Vector2 operator -(Vector2 other) => Vector2(x - other.x, y - other.y);
  Vector2 operator *(double scalar) => Vector2(x * scalar, y * scalar);
  
  double get length => math.sqrt(x * x + y * y);
  Vector2 normalized() {
    double len = length;
    return len > 0 ? Vector2(x / len, y / len) : Vector2(0, 0);
  }
}

class GameObject {
  Vector2 position;
  Vector2 velocity;
  double rotation;
  double radius;
  bool active;
  
  GameObject(this.position, this.velocity, this.rotation, this.radius) : active = true;
  
  void update(double dt, Size screenSize) {
    position = position + velocity * dt;
    wrapPosition(screenSize);
  }
  
  void wrapPosition(Size screenSize) {
    if (position.x < -radius) position.x = screenSize.width + radius;
    if (position.x > screenSize.width + radius) position.x = -radius;
    if (position.y < -radius) position.y = screenSize.height + radius;
    if (position.y > screenSize.height + radius) position.y = -radius;
  }
  
  bool collidesWith(GameObject other) {
    double dx = position.x - other.position.x;
    double dy = position.y - other.position.y;
    double distance = math.sqrt(dx * dx + dy * dy);
    return distance < (radius + other.radius);
  }
}

class Ship extends GameObject {
  bool thrusting = false;
  double thrustPower = 250.0;
  double rotationSpeed = 5.0;
  double maxSpeed = 400.0;
  double drag = 0.98;
  
  Ship(Vector2 position) : super(position, Vector2(0, 0), -math.pi / 2, 12);
  
  void rotateLeft(double dt) {
    rotation -= rotationSpeed * dt;
  }
  
  void rotateRight(double dt) {
    rotation += rotationSpeed * dt;
  }
  
  void thrust(double dt) {
    thrusting = true;
    double thrustX = math.cos(rotation) * thrustPower * dt;
    double thrustY = math.sin(rotation) * thrustPower * dt;
    velocity = velocity + Vector2(thrustX, thrustY);
    
    if (velocity.length > maxSpeed) {
      velocity = velocity.normalized() * maxSpeed;
    }
  }
  
  void stopThrust() {
    thrusting = false;
  }
  
  @override
  void update(double dt, Size screenSize) {
    velocity = velocity * drag;
    super.update(dt, screenSize);
  }
  
  Bullet shoot() {
    double bulletSpeed = 500.0;
    Vector2 direction = Vector2(math.cos(rotation), math.sin(rotation));
    Vector2 bulletVelocity = direction * bulletSpeed + velocity;
    Vector2 bulletPosition = position + direction * (radius + 8);
    
    return Bullet(bulletPosition, bulletVelocity);
  }
}

class Bullet extends GameObject {
  double lifeTime = 1.8;
  double age = 0.0;
  
  Bullet(Vector2 position, Vector2 velocity) : super(position, velocity, 0, 3);
  
  @override
  void update(double dt, Size screenSize) {
    age += dt;
    if (age > lifeTime) {
      active = false;
    }
    super.update(dt, screenSize);
  }
}

enum AsteroidSize { large, medium, small }

class Asteroid extends GameObject {
  AsteroidSize size;
  List<Vector2> shape = [];
  double rotationSpeed;
  
  Asteroid(Vector2 position, Vector2 velocity, this.size) 
    : rotationSpeed = (math.Random().nextDouble() - 0.5) * 2.0,
      super(position, velocity, math.Random().nextDouble() * 2 * math.pi, _getRadius(size)) {
    _generateShape();
  }
  
  static double _getRadius(AsteroidSize size) {
    switch (size) {
      case AsteroidSize.large: return 45;
      case AsteroidSize.medium: return 28;
      case AsteroidSize.small: return 18;
    }
  }
  
  void _generateShape() {
    shape = [];
    int vertices = 8 + math.Random().nextInt(4);
    for (int i = 0; i < vertices; i++) {
      double angle = (i / vertices) * 2 * math.pi;
      double r = radius * (0.6 + math.Random().nextDouble() * 0.4);
      shape.add(Vector2(math.cos(angle) * r, math.sin(angle) * r));
    }
  }
  
  @override
  void update(double dt, Size screenSize) {
    rotation += rotationSpeed * dt;
    super.update(dt, screenSize);
  }
  
  List<Asteroid> split() {
    if (size == AsteroidSize.small) return [];
    
    AsteroidSize newSize = size == AsteroidSize.large ? AsteroidSize.medium : AsteroidSize.small;
    List<Asteroid> fragments = [];
    
    int numFragments = 2 + math.Random().nextInt(2); // 2-3 fragments
    
    for (int i = 0; i < numFragments; i++) {
      double angle = (i / numFragments) * 2 * math.pi + math.Random().nextDouble() * 0.5;
      double speed = 80 + math.Random().nextDouble() * 120;
      Vector2 newVelocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed
      ) + velocity * 0.3;
      
      Vector2 offset = Vector2(
        math.cos(angle) * radius * 0.3,
        math.sin(angle) * radius * 0.3
      );
      
      fragments.add(Asteroid(position + offset, newVelocity, newSize));
    }
    
    return fragments;
  }
}

class Particle {
  Vector2 position;
  Vector2 velocity;
  double life;
  double maxLife;
  Color color;
  
  Particle(this.position, this.velocity, this.maxLife, this.color) : life = maxLife;
  
  void update(double dt) {
    position = position + velocity * dt;
    life -= dt;
    velocity = velocity * 0.95; // Slow down over time
  }
  
  bool get isDead => life <= 0;
  
  double get opacity => life / maxLife;
}

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late AnimationController _gameController;
  late Ship ship;
  List<Bullet> bullets = [];
  List<Asteroid> asteroids = [];
  List<Particle> particles = [];
  
  Set<LogicalKeyboardKey> pressedKeys = {};
  int score = 0;
  int lives = 3;
  int level = 1;
  bool gameOver = false;
  bool gameStarted = false;
  
  double lastShootTime = 0;
  final double shootCooldown = 0.15;
  
  late DateTime lastFrameTime;
  
  @override
  void initState() {
    super.initState();
    lastFrameTime = DateTime.now();
    
    _gameController = AnimationController(
      duration: Duration(milliseconds: 16),
      vsync: this,
    )..addListener(_gameLoop);
    
    _initializeGame();
  }
  
  void _initializeGame() {
    ship = Ship(Vector2(400, 300));
    bullets.clear();
    asteroids.clear();
    particles.clear();
    
    _spawnAsteroids();
  }
  
  void _spawnAsteroids() {
    int numAsteroids = 4 + level;
    
    for (int i = 0; i < numAsteroids; i++) {
      Vector2 position;
      do {
        position = Vector2(
          math.Random().nextDouble() * 800,
          math.Random().nextDouble() * 600
        );
      } while ((position - ship.position).length < 120);
      
      double speed = 30 + level * 10 + math.Random().nextDouble() * 40;
      double angle = math.Random().nextDouble() * 2 * math.pi;
      Vector2 velocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed
      );
      
      asteroids.add(Asteroid(position, velocity, AsteroidSize.large));
    }
  }
  
  void _startGame() {
    setState(() {
      gameStarted = true;
      gameOver = false;
      score = 0;
      lives = 3;
      level = 1;
      _initializeGame();
      _gameController.repeat();
    });
  }
  
  void _gameLoop() {
    if (!gameStarted || gameOver) return;
    
    DateTime currentTime = DateTime.now();
    double dt = (currentTime.millisecondsSinceEpoch - lastFrameTime.millisecondsSinceEpoch) / 1000.0;
    dt = dt.clamp(0.0, 0.05); // Cap delta time to prevent large jumps
    lastFrameTime = currentTime;
    
    _handleInput(dt);
    _updateGameObjects(dt);
    _checkCollisions();
    _updateParticles(dt);
    
    if (mounted) setState(() {});
  }
  
  void _handleInput(double dt) {
    if (pressedKeys.contains(LogicalKeyboardKey.arrowLeft) || 
        pressedKeys.contains(LogicalKeyboardKey.keyA)) {
      ship.rotateLeft(dt);
    }
    if (pressedKeys.contains(LogicalKeyboardKey.arrowRight) || 
        pressedKeys.contains(LogicalKeyboardKey.keyD)) {
      ship.rotateRight(dt);
    }
    if (pressedKeys.contains(LogicalKeyboardKey.arrowUp) || 
        pressedKeys.contains(LogicalKeyboardKey.keyW)) {
      ship.thrust(dt);
    } else {
      ship.stopThrust();
    }
    if (pressedKeys.contains(LogicalKeyboardKey.space)) {
      _tryShoot();
    }
  }
  
  void _tryShoot() {
    double currentTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (currentTime - lastShootTime > shootCooldown) {
      bullets.add(ship.shoot());
      lastShootTime = currentTime;
    }
  }
  
  void _updateGameObjects(double dt) {
    Size screenSize = Size(800, 600);
    
    ship.update(dt, screenSize);
    
    bullets.removeWhere((bullet) => !bullet.active);
    for (Bullet bullet in bullets) {
      bullet.update(dt, screenSize);
    }
    
    for (Asteroid asteroid in asteroids) {
      asteroid.update(dt, screenSize);
    }
  }
  
  void _updateParticles(double dt) {
    particles.removeWhere((particle) => particle.isDead);
    for (Particle particle in particles) {
      particle.update(dt);
    }
  }
  
  void _createExplosion(Vector2 position, int numParticles, Color color) {
    for (int i = 0; i < numParticles; i++) {
      double angle = math.Random().nextDouble() * 2 * math.pi;
      double speed = 50 + math.Random().nextDouble() * 150;
      Vector2 velocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed
      );
      
      particles.add(Particle(
        Vector2(position.x, position.y),
        velocity,
        0.8 + math.Random().nextDouble() * 0.4,
        color.withValues(alpha: 1.0)
      ));
    }
  }
  
  void _checkCollisions() {
    // Bullet-Asteroid collisions
    for (int i = bullets.length - 1; i >= 0; i--) {
      for (int j = asteroids.length - 1; j >= 0; j--) {
        if (i < bullets.length && j < asteroids.length && 
            bullets[i].collidesWith(asteroids[j])) {
          
          Vector2 hitPosition = asteroids[j].position;
          
          // Score points
          switch (asteroids[j].size) {
            case AsteroidSize.large: score += 20; break;
            case AsteroidSize.medium: score += 50; break;
            case AsteroidSize.small: score += 100; break;
          }
          
          // Create explosion
          _createExplosion(hitPosition, 8, Colors.orange);
          
          // Split asteroid
          List<Asteroid> fragments = asteroids[j].split();
          asteroids.addAll(fragments);
          
          // Remove bullet and asteroid
          bullets.removeAt(i);
          asteroids.removeAt(j);
          break;
        }
      }
    }
    
    // Ship-Asteroid collisions
    for (int i = 0; i < asteroids.length; i++) {
      if (ship.collidesWith(asteroids[i])) {
        _createExplosion(ship.position, 15, Colors.red);
        
        lives--;
        if (lives <= 0) {
          gameOver = true;
          _gameController.stop();
        } else {
          // Reset ship position safely
          Vector2 safePosition;
          bool positionFound = false;
          int attempts = 0;
          
          while (!positionFound && attempts < 50) {
            safePosition = Vector2(
              100 + math.Random().nextDouble() * 600,
              100 + math.Random().nextDouble() * 400
            );
            
            positionFound = true;
            for (Asteroid asteroid in asteroids) {
              if ((safePosition - asteroid.position).length < 100) {
                positionFound = false;
                break;
              }
            }
            
            if (positionFound) {
              ship.position = safePosition;
              ship.velocity = Vector2(0, 0);
            }
            attempts++;
          }
          
          if (!positionFound) {
            ship.position = Vector2(400, 300);
            ship.velocity = Vector2(0, 0);
          }
        }
        break;
      }
    }
    
    // Check level completion
    if (asteroids.isEmpty && !gameOver) {
      _nextLevel();
    }
  }
  
  void _nextLevel() {
    level++;
    _spawnAsteroids();
  }
  
  void _restartGame() {
    setState(() {
      gameOver = false;
      gameStarted = false;
      score = 0;
      lives = 3;
      level = 1;
      pressedKeys.clear();
      _gameController.stop();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            pressedKeys.add(event.logicalKey);
          } else if (event is KeyUpEvent) {
            pressedKeys.remove(event.logicalKey);
          }
          return KeyEventResult.handled;
        },
        child: SizedBox(
          width: 800,
          height: 600,
          child: Stack(
            children: [
              if (gameStarted)
                CustomPaint(
                  painter: GamePainter(ship, bullets, asteroids, particles),
                  size: Size(800, 600),
                ),
              
              // UI Overlay
              if (gameStarted) ...[
                Positioned(
                  top: 20,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SCORE: $score', 
                        style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'monospace')),
                      Text('LIVES: $lives', 
                        style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'monospace')),
                      Text('LEVEL: $level', 
                        style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WASD or Arrow Keys: Move & Rotate', 
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text('SPACE: Shoot', 
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
              
              // Start Screen
              if (!gameStarted && !gameOver)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('ASTEROIDS', 
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 64, 
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold
                        )),
                      SizedBox(height: 40),
                      Text('Destroy all asteroids to advance levels!', 
                        style: TextStyle(color: Colors.white70, fontSize: 18)),
                      SizedBox(height: 20),
                      Text('WASD or Arrow Keys to move', 
                        style: TextStyle(color: Colors.white54, fontSize: 16)),
                      Text('SPACE to shoot', 
                        style: TextStyle(color: Colors.white54, fontSize: 16)),
                      SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: _startGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        ),
                        child: Text('START GAME', 
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              
              // Game Over Screen
              if (gameOver)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('GAME OVER', 
                        style: TextStyle(
                          color: Colors.red, 
                          fontSize: 48, 
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold
                        )),
                      SizedBox(height: 20),
                      Text('Final Score: $score', 
                        style: TextStyle(color: Colors.white, fontSize: 24)),
                      Text('Level Reached: $level', 
                        style: TextStyle(color: Colors.white, fontSize: 20)),
                      SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: _restartGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        ),
                        child: Text('PLAY AGAIN', 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _gameController.dispose();
    super.dispose();
  }
}

class GamePainter extends CustomPainter {
  final Ship ship;
  final List<Bullet> bullets;
  final List<Asteroid> asteroids;
  final List<Particle> particles;
  
  GamePainter(this.ship, this.bullets, this.asteroids, this.particles);
  
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // Draw ship
    _drawShip(canvas, paint);
    
    // Draw bullets
    Paint bulletPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    for (Bullet bullet in bullets) {
      canvas.drawCircle(
        Offset(bullet.position.x, bullet.position.y),
        bullet.radius,
        bulletPaint,
      );
    }
    
    // Draw asteroids
    for (Asteroid asteroid in asteroids) {
      _drawAsteroid(canvas, paint, asteroid);
    }
    
    // Draw particles
    for (Particle particle in particles) {
      Paint particlePaint = Paint()
        ..color = particle.color.withValues(alpha: particle.opacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(particle.position.x, particle.position.y),
        2.0,
        particlePaint,
      );
    }
  }
  
  void _drawShip(Canvas canvas, Paint paint) {
    canvas.save();
    canvas.translate(ship.position.x, ship.position.y);
    canvas.rotate(ship.rotation);
    
    Path shipPath = Path();
    shipPath.moveTo(15, 0);
    shipPath.lineTo(-10, -8);
    shipPath.lineTo(-5, 0);
    shipPath.lineTo(-10, 8);
    shipPath.close();
    
    canvas.drawPath(shipPath, paint);
    
    // Draw thrust flame
    if (ship.thrusting) {
      Paint thrustPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.fill;
      
      Path thrustPath = Path();
      thrustPath.moveTo(-10, -4);
      thrustPath.lineTo(-20, 0);
      thrustPath.lineTo(-10, 4);
      thrustPath.close();
      
      canvas.drawPath(thrustPath, thrustPaint);
    }
    
    canvas.restore();
  }
  
  void _drawAsteroid(Canvas canvas, Paint paint, Asteroid asteroid) {
    canvas.save();
    canvas.translate(asteroid.position.x, asteroid.position.y);
    canvas.rotate(asteroid.rotation);
    
    Path asteroidPath = Path();
    if (asteroid.shape.isNotEmpty) {
      asteroidPath.moveTo(asteroid.shape[0].x, asteroid.shape[0].y);
      for (int i = 1; i < asteroid.shape.length; i++) {
        asteroidPath.lineTo(asteroid.shape[i].x, asteroid.shape[i].y);
      }
      asteroidPath.close();
    }
    
    canvas.drawPath(asteroidPath, paint);
    canvas.restore();
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}