import React, { useState, useEffect, useMemo } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { DrawingCanvas } from '../components/Canvas/DrawingCanvas';
import { ScoreBoard } from '../components/UI/ScoreBoard';
import useGameStore from '../store/gameStore';
import { getAllWords } from '../utils/wordBank';
import './GuessingPage.css';

export const GuessingPage: React.FC = () => {
  const { gameId } = useParams<{ gameId: string }>();
  const navigate = useNavigate();
  const { currentGame, joinGame, makeGuess } = useGameStore();
  const [guessInput, setGuessInput] = useState('');
  const [playerName, setPlayerName] = useState('');
  const [hasJoined, setHasJoined] = useState(false);
  const [suggestions, setSuggestions] = useState<string[]>([]);
  const allWords = useMemo(() => getAllWords(), []);

  useEffect(() => {
    if (!gameId) {
      navigate('/');
      return;
    }

    if (!currentGame || currentGame.id !== gameId) {
      // Check if game exists in history
      const gameExists = useGameStore.getState().gameHistory.some(g => g.id === gameId);
      if (!gameExists && (!currentGame || currentGame.id !== gameId)) {
        alert('Game not found!');
        navigate('/');
      }
    }
  }, [gameId, currentGame, navigate]);

  useEffect(() => {
    if (guessInput.length > 1) {
      const filtered = allWords.filter(word => 
        word.toLowerCase().startsWith(guessInput.toLowerCase())
      ).slice(0, 5);
      setSuggestions(filtered);
    } else {
      setSuggestions([]);
    }
  }, [guessInput, allWords]);

  const handleJoinGame = () => {
    if (!playerName.trim()) {
      alert('Please enter your name');
      return;
    }
    
    if (gameId) {
      joinGame(gameId, playerName);
      setHasJoined(true);
    }
  };

  const handleGuess = () => {
    if (!guessInput.trim()) return;
    
    makeGuess(guessInput);
    setGuessInput('');
  };

  const handleSuggestionClick = (suggestion: string) => {
    setGuessInput(suggestion);
    setSuggestions([]);
  };

  if (!currentGame) return null;

  if (!hasJoined) {
    return (
      <div className="guessing-page">
        <motion.div 
          className="join-container"
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.5 }}
        >
          <h1>Join Game</h1>
          <p>{currentGame.drawer.name} has drawn something for you to guess!</p>
          
          <div className="join-form">
            <input
              type="text"
              value={playerName}
              onChange={(e) => setPlayerName(e.target.value)}
              placeholder="Enter your name"
              className="name-input"
              maxLength={20}
            />
            <button onClick={handleJoinGame} className="join-button">
              Join & Start Guessing
            </button>
          </div>
        </motion.div>
      </div>
    );
  }

  const isGameOver = currentGame.status === 'finished' || currentGame.guesses.length >= 5;
  const hasWon = currentGame.guesses.some(g => g.isCorrect);

  return (
    <div className="guessing-page">
      <motion.div 
        className="guessing-container"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.5 }}
      >
        <ScoreBoard 
          player1={currentGame.drawer}
          player2={currentGame.guesser}
          currentRound={currentGame.currentRound}
          totalRounds={currentGame.roundsTotal}
          mode={currentGame.mode}
        />
        
        <div className="game-header">
          <div className="drawer-info">
            <span className="label">Drawn by:</span>
            <span className="name">{currentGame.drawer.name}</span>
          </div>
          
          <div className="attempts-counter">
            <span className="label">Attempts:</span>
            <span className="count">{currentGame.guesses.length}/5</span>
          </div>
        </div>

        <div className="drawing-display">
          <DrawingCanvas readOnly drawingData={currentGame.drawing} />
        </div>

        {!isGameOver && (
          <div className="guess-section">
            <div className="guess-input-container">
              <input
                type="text"
                value={guessInput}
                onChange={(e) => setGuessInput(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleGuess()}
                placeholder="What is this drawing?"
                className="guess-input"
                autoComplete="off"
              />
              <button onClick={handleGuess} className="guess-button">
                Guess
              </button>
            </div>
            
            {suggestions.length > 0 && (
              <div className="suggestions">
                {suggestions.map(suggestion => (
                  <button
                    key={suggestion}
                    onClick={() => handleSuggestionClick(suggestion)}
                    className="suggestion-item"
                  >
                    {suggestion}
                  </button>
                ))}
              </div>
            )}
          </div>
        )}

        <div className="guesses-history">
          <h3>Your Guesses</h3>
          <div className="guesses-list">
            {currentGame.guesses.map((guess, index) => (
              <motion.div
                key={index}
                className={`guess-item ${guess.isCorrect ? 'correct' : 'incorrect'}`}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.1 }}
              >
                <span className="guess-text">{guess.word}</span>
                <span className="guess-result">{guess.isCorrect ? '✓' : '✗'}</span>
              </motion.div>
            ))}
          </div>
        </div>

        {isGameOver && (
          <motion.div 
            className="game-over"
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: 0.5 }}
          >
            <h2>{hasWon ? 'You Won! 🎉' : 'Game Over'}</h2>
            <p>The word was: <strong>{currentGame.currentWord}</strong></p>
            
            {currentGame.mode === 'wager' && (
              <div className="coins-result">
                {hasWon ? (
                  <p>You won {currentGame.wagerAmount || 0} coins! 🪙</p>
                ) : (
                  <p>Better luck next time!</p>
                )}
              </div>
            )}
            
            <button onClick={() => navigate('/')} className="play-again-button">
              Play Again
            </button>
          </motion.div>
        )}
      </motion.div>
    </div>
  );
};