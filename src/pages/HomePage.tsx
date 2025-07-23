import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import useGameStore from '../store/gameStore';
import { GameMode, Difficulty } from '../types/game';
import './HomePage.css';

export const HomePage: React.FC = () => {
  const navigate = useNavigate();
  const { createGame, playerStats } = useGameStore();
  const [playerName, setPlayerName] = useState('');
  const [selectedMode, setSelectedMode] = useState<GameMode>('bestOf');
  const [selectedDifficulty, setSelectedDifficulty] = useState<Difficulty>('medium');
  const [bestOfRounds, setBestOfRounds] = useState(3);

  const handleStartGame = () => {
    if (!playerName.trim()) {
      alert('Please enter your name');
      return;
    }

    createGame(selectedMode, selectedDifficulty, playerName, bestOfRounds);
    navigate('/draw');
  };

  return (
    <div className="home-page">
      <motion.div 
        className="home-container"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
      >
        <h1 className="game-title">Pictionary</h1>
        <p className="game-subtitle">Draw, Share, Guess!</p>

        <div className="stats-banner">
          <div className="stat-item">
            <span className="stat-label">Total Games</span>
            <span className="stat-value">{playerStats.totalGames}</span>
          </div>
          <div className="stat-item">
            <span className="stat-label">Wins</span>
            <span className="stat-value">{playerStats.totalWins}</span>
          </div>
          <div className="stat-item">
            <span className="stat-label">Coins Won</span>
            <span className="stat-value">{playerStats.coinsWon}</span>
          </div>
        </div>

        <div className="game-setup">
          <div className="input-group">
            <label htmlFor="playerName">Your Name</label>
            <input
              id="playerName"
              type="text"
              value={playerName}
              onChange={(e) => setPlayerName(e.target.value)}
              placeholder="Enter your name"
              className="name-input"
              maxLength={20}
            />
          </div>

          <div className="mode-selection">
            <h3>Game Mode</h3>
            <div className="mode-buttons">
              <button
                className={`mode-button ${selectedMode === 'bestOf' ? 'selected' : ''}`}
                onClick={() => setSelectedMode('bestOf')}
              >
                <span className="mode-icon">🏆</span>
                <span className="mode-name">Best of X</span>
                <span className="mode-desc">Race to win majority</span>
              </button>
              <button
                className={`mode-button ${selectedMode === 'wager' ? 'selected' : ''}`}
                onClick={() => setSelectedMode('wager')}
              >
                <span className="mode-icon">🪙</span>
                <span className="mode-name">Wager Mode</span>
                <span className="mode-desc">Bet coins on each round</span>
              </button>
            </div>
          </div>

          {selectedMode === 'bestOf' && (
            <div className="rounds-selection">
              <h3>Best of</h3>
              <div className="rounds-buttons">
                {[3, 5, 7, 9].map(num => (
                  <button
                    key={num}
                    className={`round-button ${bestOfRounds === num ? 'selected' : ''}`}
                    onClick={() => setBestOfRounds(num)}
                  >
                    {num}
                  </button>
                ))}
              </div>
            </div>
          )}

          <div className="difficulty-selection">
            <h3>Difficulty</h3>
            <div className="difficulty-buttons">
              <button
                className={`difficulty-button ${selectedDifficulty === 'easy' ? 'selected' : ''}`}
                onClick={() => setSelectedDifficulty('easy')}
              >
                Easy
              </button>
              <button
                className={`difficulty-button ${selectedDifficulty === 'medium' ? 'selected' : ''}`}
                onClick={() => setSelectedDifficulty('medium')}
              >
                Medium
              </button>
              <button
                className={`difficulty-button ${selectedDifficulty === 'hard' ? 'selected' : ''}`}
                onClick={() => setSelectedDifficulty('hard')}
              >
                Hard
              </button>
            </div>
          </div>

          <motion.button
            className="start-button"
            onClick={handleStartGame}
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
          >
            Start New Game
          </motion.button>
        </div>
      </motion.div>
    </div>
  );
};