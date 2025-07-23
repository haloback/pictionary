import React from 'react';
import { motion } from 'framer-motion';
import { Player } from '../../types/game';
import './ScoreBoard.css';

interface ScoreBoardProps {
  player1?: Player;
  player2?: Player;
  currentRound?: number;
  totalRounds?: number;
  mode: 'bestOf' | 'wager';
}

export const ScoreBoard: React.FC<ScoreBoardProps> = ({ 
  player1, 
  player2, 
  currentRound = 1, 
  totalRounds,
  mode 
}) => {
  return (
    <motion.div 
      className="scoreboard"
      initial={{ opacity: 0, y: -20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
    >
      <div className="scoreboard-content">
        {mode === 'bestOf' && totalRounds && (
          <div className="round-info">
            <span className="round-label">Round</span>
            <span className="round-count">{currentRound} / {totalRounds}</span>
          </div>
        )}

        <div className="players-score">
          <div className="player-card player1">
            <div className="player-name">{player1?.name || 'Player 1'}</div>
            {mode === 'wager' ? (
              <div className="player-coins">
                <span className="coin-icon">🪙</span>
                <span className="coin-amount">{player1?.coins || 10}</span>
              </div>
            ) : (
              <div className="player-wins">
                <span className="wins-label">Wins</span>
                <span className="wins-count">{player1?.wins || 0}</span>
              </div>
            )}
          </div>

          <div className="vs-divider">VS</div>

          <div className="player-card player2">
            <div className="player-name">{player2?.name || 'Waiting...'}</div>
            {mode === 'wager' ? (
              <div className="player-coins">
                <span className="coin-icon">🪙</span>
                <span className="coin-amount">{player2?.coins || 10}</span>
              </div>
            ) : (
              <div className="player-wins">
                <span className="wins-label">Wins</span>
                <span className="wins-count">{player2?.wins || 0}</span>
              </div>
            )}
          </div>
        </div>
      </div>
    </motion.div>
  );
};