import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { DrawingCanvas } from '../components/Canvas/DrawingCanvas';
import { ShareLink } from '../components/UI/ShareLink';
import { ScoreBoard } from '../components/UI/ScoreBoard';
import useGameStore from '../store/gameStore';
import { getRandomWord } from '../utils/wordBank';
import { DrawingData } from '../types/game';
import './DrawingPage.css';

export const DrawingPage: React.FC = () => {
  const navigate = useNavigate();
  const { currentGame, submitDrawing } = useGameStore();
  const [timeLeft, setTimeLeft] = useState(120);
  const [currentWord, setCurrentWord] = useState('');
  const [showShareLink, setShowShareLink] = useState(false);

  useEffect(() => {
    if (!currentGame) {
      navigate('/');
      return;
    }

    // Only set word once when component mounts
    if (!currentWord) {
      const word = getRandomWord(currentGame.difficulty);
      setCurrentWord(word);
      
      useGameStore.setState(state => ({
        currentGame: {
          ...state.currentGame!,
          currentWord: word,
          status: 'drawing'
        }
      }));
    }
  }, [currentGame, navigate, currentWord]);

  const handleTimeUp = useCallback(() => {
    alert('Time\'s up! Submit your drawing.');
  }, []);

  useEffect(() => {
    const timer = setInterval(() => {
      setTimeLeft(prev => {
        if (prev <= 1) {
          handleTimeUp();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(timer);
  }, [handleTimeUp]);

  const handleDrawingComplete = (drawing: DrawingData) => {
    if (!currentGame) return;
    
    submitDrawing(drawing);
    setShowShareLink(true);
  };

  const handleContinue = () => {
    navigate('/');
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  if (!currentGame) return null;

  return (
    <div className="drawing-page">
      <motion.div 
        className="drawing-container"
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
        
        <div className="drawing-header">
          <div className="player-info">
            <span className="player-label">Drawing as:</span>
            <span className="player-name">{currentGame.drawer.name}</span>
          </div>
          
          <div className="timer-container">
            <div className={`timer ${timeLeft < 30 ? 'warning' : ''}`}>
              {formatTime(timeLeft)}
            </div>
          </div>
        </div>

        <div className="word-display">
          <h2>Draw: <span className="word">{currentWord}</span></h2>
          <p className="word-hint">Remember: This is a physical object!</p>
        </div>

        <DrawingCanvas onDrawingComplete={handleDrawingComplete} />

        {currentGame.mode === 'wager' && (
          <div className="wager-info">
            <div className="coin-display">
              <span className="coin-icon">🪙</span>
              <span className="coin-count">{currentGame.drawer.coins}</span>
            </div>
          </div>
        )}
      </motion.div>

      {showShareLink && currentGame && (
        <ShareLink 
          shareUrl={currentGame.shareUrl} 
          onContinue={handleContinue}
        />
      )}
    </div>
  );
};