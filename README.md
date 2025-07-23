# 🎨 Ultimate Asynchronous Pictionary Web App

A modern, mobile-responsive Pictionary game where players can draw and guess asynchronously. One player draws, shares a unique link, and the other player guesses whenever convenient!

## ✨ Features

- **Asynchronous Gameplay**: Players don't need to be online at the same time
- **Unique Shareable Links**: Each game gets a unique URL to share
- **Multi-Input Drawing**: Support for touch (mobile) and mouse (desktop)
- **200+ Words**: Physical objects across 3 difficulty levels
- **Game Modes**: 
  - 🏆 Best of X (3, 5, 7, or 9 rounds)
  - 🪙 Wager Mode (bet coins on drawings)
- **Modern UI**: Bright gradients, smooth animations, and clean design
- **Score Tracking**: Real-time score display for both players
- **Auto-Complete**: Suggestions while guessing
- **Mobile Responsive**: Works perfectly on all devices

## 🚀 Getting Started

### Prerequisites
- Node.js (v14 or higher)
- npm or yarn

### Installation

1. Clone the repository:
```bash
git clone [your-repo-url]
cd pictionary-app
```

2. Install dependencies:
```bash
npm install
```

3. Start the development server:
```bash
npm start
```

4. Open [http://localhost:3000](http://localhost:3000) in your browser

## 🎮 How to Play

1. **Player 1 (Drawer)**:
   - Enter your name
   - Choose game mode and difficulty
   - Draw the given word
   - Share the generated link with your friend

2. **Player 2 (Guesser)**:
   - Open the shared link
   - Enter your name
   - View the drawing and make guesses (max 5 attempts)
   - See if you guessed correctly!

## 🛠 Tech Stack

- **Frontend**: React with TypeScript
- **Styling**: CSS with modern gradients and animations
- **State Management**: Zustand with persistence
- **Routing**: React Router
- **Animations**: Framer Motion
- **Drawing**: HTML5 Canvas API

## 📱 Features in Detail

### Drawing Tools
- Multiple brush sizes (thin, medium, thick)
- 6 color palette
- Undo functionality
- Clear canvas option
- 2-minute timer

### Game Features
- Local storage persistence
- Game history tracking
- Player statistics
- Share via WhatsApp or Email
- Copy link to clipboard

## 🏗 Project Structure

```
src/
├── components/
│   ├── Canvas/         # Drawing canvas component
│   └── UI/            # ShareLink, ScoreBoard components
├── pages/             # Main app pages
├── store/             # Zustand store
├── types/             # TypeScript interfaces
├── utils/             # Word bank and utilities
└── styles/            # CSS files
```

## 📝 Available Scripts

- `npm start` - Run development server
- `npm build` - Build for production
- `npm test` - Run tests
- `npm eject` - Eject from Create React App

## 🎨 Customization

You can customize:
- Word bank in `src/utils/wordBank.ts`
- Colors and styling in CSS files
- Game modes in `src/store/gameStore.ts`
- Drawing tools in `src/components/Canvas/DrawingCanvas.tsx`

## 📄 License

This project is private and proprietary.

## 🤝 Contributing

This is a private repository. Please contact the owner for contribution guidelines.

---

Built with ❤️ using React and TypeScript
