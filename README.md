# Snake Online 🐍

A modern, multiplayer recreation of the classic Snake game built with Flutter. Relive the nostalgia of the original mobile Snake game with real-time online multiplayer, trophy system, and leaderboards!

## Features

### ✨ Core Features
- **Play Online**: Real-time multiplayer matches with automatic matchmaking
- **Play Local**: Classic single-player Snake experience
- **Leaderboard**: Global rankings with trophy system
- **Settings**: Customizable game options (sound, speed, controls)
- **Google Sign-In**: Secure authentication and progress tracking

### 🎮 Game Features
- **Low-latency multiplayer** using Socket.IO for real-time gameplay
- **Trophy system**: Win +3, Lose -1 trophies
- **Retro-themed UI** with nostalgic green color scheme
- **Animated menu** with classic Snake styling
- **Robust collision detection** for fair competitive play

### 🔧 Technical Features
- **Flutter** for cross-platform mobile development
- **Firebase Auth** for secure user authentication
- **Socket.IO** for real-time communication
- **Provider** for state management
- **SharedPreferences** for local settings storage

## Getting Started

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Android Studio / VS Code with Flutter extensions
- Firebase project (for authentication)
- Node.js server with Socket.IO (for multiplayer)

### Installation

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd snake_online
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup** (Required for authentication)
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable Authentication with Google Sign-In
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in `android/app/` and `ios/Runner/` respectively
   - Run: `flutter packages pub run build_runner build`

4. **Socket.IO Server Setup** (Required for multiplayer)
   - Set up a Node.js server with Socket.IO
   - Update the server URL in `lib/services/socket_service.dart`
   - Implement game logic endpoints for matchmaking and game state synchronization

5. **Run the app**
   ```bash
   flutter run
   ```

### Server Requirements

For full multiplayer functionality, you'll need a backend server that handles:

- **WebSocket connections** (Socket.IO)
- **Matchmaking system** (player queuing and pairing)
- **Game state synchronization** (real-time game updates)
- **User data persistence** (trophies, statistics)
- **Leaderboard management** (global rankings)

Example server events to implement:
```javascript
// Client -> Server
'find_match'      // Start matchmaking
'cancel_matchmaking'  // Cancel search
'player_move'     // Send player direction
'leave_game'      // Quit current game

// Server -> Client  
'match_found'     // Match created
'game_start'      // Game begins
'game_state_update'   // Sync game state
'game_end'        // Game finished
'opponent_left'   // Opponent disconnected
```

## Project Structure

```
lib/
├── main.dart                 # App entry point with providers
├── models/                   # Data models
│   ├── user_model.dart      # User/player data
│   ├── snake_model.dart     # Snake and game logic
│   └── game_state.dart      # Game state management
├── services/                # Business logic services
│   ├── auth_service.dart    # Google authentication
│   ├── socket_service.dart  # Real-time communication
│   └── settings_service.dart # App preferences
├── screens/                 # UI screens
│   └── main_menu_screen.dart # Initial menu
├── widgets/                 # Reusable UI components
│   └── menu_widgets.dart    # Custom menu buttons
└── utils/                   # Utilities and constants
    └── theme.dart           # App theming and colors
```

## Current Status

This is the **initial setup** with:
- ✅ Main menu with retro Snake styling
- ✅ Google Sign-In integration
- ✅ Settings service foundation
- ✅ Socket.IO service foundation
- ✅ Comprehensive models and state management
- ⏳ Game screens (coming next)
- ⏳ Actual Socket.IO server implementation
- ⏳ Leaderboard functionality

## Next Steps

1. **Implement game screens**: Local and online game UI
2. **Create Socket.IO server**: Backend game logic and matchmaking
3. **Add game mechanics**: Snake movement, collision detection, food generation
4. **Implement leaderboard**: Rankings and statistics display
5. **Add settings screen**: Customize game preferences
6. **Audio system**: Retro game sounds and background music
7. **Testing and polishing**: Bug fixes and performance optimization

## Contributing

1. Fork the repository
2. Create a feature branch
3. Implement your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by the classic Nokia Snake game
- Built with Flutter's powerful cross-platform framework
- Real-time multiplayer powered by Socket.IO

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
