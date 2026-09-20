enum Direction { up, down, left, right }

enum GameStatus { waiting, playing, paused, gameOver, disconnected }

class Position {
  final int x;
  final int y;

  const Position(this.x, this.y);

  Position operator +(Position other) {
    return Position(x + other.x, y + other.y);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Position && other.x == x && other.y == y;
  }

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(json['x'] ?? 0, json['y'] ?? 0);
  }

  @override
  String toString() => 'Position($x, $y)';
}

class Snake {
  List<Position> body;
  List<Position> previousBody;
  Direction direction;
  Direction previousDirection;
  Direction? nextDirection;
  bool isAlive;
  int pendingGrowth;

  Snake({
    required this.body,
    List<Position>? previousBody,
    this.direction = Direction.right,
    Direction? previousDirection,
    this.nextDirection,
    this.isAlive = true,
    this.pendingGrowth = 0,
  })  : previousBody = previousBody ?? List.from(body),
        previousDirection = previousDirection ?? direction;

  Position get head => body.first;

  void grow(int amount) {
    if (amount > 0) {
      pendingGrowth += amount;
    }
  }

  void move(Position food, {int growthAmount = 1}) {
    previousBody = List<Position>.from(body);
    previousDirection = direction;

    if (nextDirection != null) {
      // Prevent immediate reversal
      if (!_isOppositeDirection(direction, nextDirection!)) {
        direction = nextDirection!;
      }
      nextDirection = null;
    }

    Position newHead = _getNextPosition();
    body.insert(0, newHead);

    // If food is eaten, snake grows by growthAmount
    if (newHead == food) {
      if (growthAmount > 1) {
        pendingGrowth += (growthAmount - 1);
      }
    } else if (pendingGrowth > 0) {
      // Consume one unit of pending growth (do not remove tail)
      pendingGrowth--;
    } else {
      body.removeLast();
    }
  }

  Position _getNextPosition() {
    switch (direction) {
      case Direction.up:
        return Position(head.x, head.y - 1);
      case Direction.down:
        return Position(head.x, head.y + 1);
      case Direction.left:
        return Position(head.x - 1, head.y);
      case Direction.right:
        return Position(head.x + 1, head.y);
    }
  }

  bool _isOppositeDirection(Direction current, Direction new_) {
    return (current == Direction.up && new_ == Direction.down) ||
           (current == Direction.down && new_ == Direction.up) ||
           (current == Direction.left && new_ == Direction.right) ||
           (current == Direction.right && new_ == Direction.left);
  }

  bool checkSelfCollision() {
    for (int i = 1; i < body.length; i++) {
      if (body[i] == head) {
        isAlive = false;
        return true;
      }
    }
    return false;
  }

  bool checkWallCollision(int gridWidth, int gridHeight) {
    if (head.x < 0 || head.x >= gridWidth || head.y < 0 || head.y >= gridHeight) {
      isAlive = false;
      return true;
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'body': body.map((pos) => pos.toJson()).toList(),
      'direction': direction.index,
      'nextDirection': nextDirection?.index,
      'isAlive': isAlive,
    };
  }

  factory Snake.fromJson(Map<String, dynamic> json) {
    return Snake(
      body: (json['body'] as List)
          .map((pos) => Position.fromJson(pos as Map<String, dynamic>))
          .toList(),
      direction: Direction.values[json['direction'] ?? 0],
      nextDirection: json['nextDirection'] != null 
          ? Direction.values[json['nextDirection']] 
          : null,
      isAlive: json['isAlive'] ?? true,
    );
  }
}
