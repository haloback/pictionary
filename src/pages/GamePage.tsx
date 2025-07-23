import React, { useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import useGameStore from '../store/gameStore';

export const GamePage: React.FC = () => {
  const { gameId } = useParams<{ gameId: string }>();
  const navigate = useNavigate();
  const { loadGame } = useGameStore();

  useEffect(() => {
    if (!gameId) {
      navigate('/');
      return;
    }

    const game = loadGame(gameId);
    
    if (!game) {
      const existingGame = useGameStore.getState().currentGame;
      if (existingGame && existingGame.id === gameId) {
        if (existingGame.status === 'waiting' || existingGame.status === 'guessing') {
          navigate(`/guess/${gameId}`);
        } else {
          navigate('/');
        }
      } else {
        alert('Game not found!');
        navigate('/');
      }
    } else {
      if (game.status === 'waiting' || game.status === 'guessing') {
        navigate(`/guess/${gameId}`);
      } else {
        alert('This game has already ended!');
        navigate('/');
      }
    }
  }, [gameId, navigate, loadGame]);

  return <div>Loading game...</div>;
};