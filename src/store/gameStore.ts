import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { Game, GameStats, Player, DrawingData, Guess } from '../types/game';
import { v4 as uuidv4 } from 'uuid';

interface GameStore {
  currentGame: Game | null;
  playerStats: GameStats;
  gameHistory: Game[];
  currentPlayer: Player | null;
  
  // Game actions
  createGame: (mode: Game['mode'], difficulty: Game['difficulty'], playerName: string, roundsTotal?: number) => void;
  joinGame: (gameId: string, playerName: string) => void;
  submitDrawing: (drawingData: DrawingData) => void;
  makeGuess: (guess: string) => void;
  updateWager: (amount: number) => void;
  endGame: () => void;
  
  // Player actions
  updatePlayerCoins: (playerId: string, amount: number) => void;
  
  // Stats actions
  updateStats: (won: boolean, coinsEarned: number) => void;
  
  // Storage actions
  loadGame: (gameId: string) => Game | null;
  saveToHistory: (game: Game) => void;
}

const useGameStore = create<GameStore>()(
  persist(
    (set, get) => ({
      currentGame: null,
      playerStats: {
        totalWins: 0,
        totalGames: 0,
        coinsWon: 0,
        favoriteWords: []
      },
      gameHistory: [],
      currentPlayer: null,

      createGame: (mode, difficulty, playerName, roundsTotal = 3) => {
        const playerId = uuidv4();
        const gameId = uuidv4();
        const player: Player = {
          id: playerId,
          name: playerName,
          coins: mode === 'wager' ? 10 : 0,
          wins: 0,
          losses: 0
        };
        
        const game: Game = {
          id: gameId,
          mode,
          status: 'waiting',
          currentWord: '',
          difficulty,
          drawer: player,
          guesses: [],
          currentRound: 1,
          roundsTotal: mode === 'bestOf' ? roundsTotal : undefined,
          timeLimit: 120,
          createdAt: Date.now(),
          shareUrl: `${window.location.origin}/game/${gameId}`
        };
        
        set({ currentGame: game, currentPlayer: player });
      },

      joinGame: (gameId, playerName) => {
        const { currentGame } = get();
        if (currentGame && currentGame.id === gameId) {
          const player: Player = {
            id: uuidv4(),
            name: playerName,
            coins: currentGame.mode === 'wager' ? 10 : 0,
            wins: 0,
            losses: 0
          };
          
          set({
            currentGame: {
              ...currentGame,
              guesser: player,
              status: 'guessing'
            },
            currentPlayer: player
          });
        }
      },

      submitDrawing: (drawingData) => {
        const { currentGame } = get();
        if (currentGame) {
          set({
            currentGame: {
              ...currentGame,
              drawing: drawingData,
              status: 'guessing'
            }
          });
        }
      },

      makeGuess: (guess) => {
        const { currentGame } = get();
        if (currentGame && currentGame.guesses.length < 5) {
          const isCorrect = guess.toLowerCase() === currentGame.currentWord.toLowerCase();
          const newGuess: Guess = {
            word: guess,
            isCorrect,
            timestamp: Date.now()
          };
          
          const updatedGuesses = [...currentGame.guesses, newGuess];
          const gameFinished = isCorrect || updatedGuesses.length >= 5;
          
          set({
            currentGame: {
              ...currentGame,
              guesses: updatedGuesses,
              status: gameFinished ? 'finished' : 'guessing'
            }
          });
          
          if (gameFinished) {
            get().updateStats(isCorrect, currentGame.wagerAmount || 0);
          }
        }
      },

      updateWager: (amount) => {
        const { currentGame } = get();
        if (currentGame && currentGame.mode === 'wager') {
          set({
            currentGame: {
              ...currentGame,
              wagerAmount: amount
            }
          });
        }
      },

      endGame: () => {
        const { currentGame } = get();
        if (currentGame) {
          get().saveToHistory(currentGame);
          set({ currentGame: null });
        }
      },

      updatePlayerCoins: (playerId, amount) => {
        const { currentGame } = get();
        if (currentGame) {
          if (currentGame.drawer.id === playerId) {
            set({
              currentGame: {
                ...currentGame,
                drawer: {
                  ...currentGame.drawer,
                  coins: currentGame.drawer.coins + amount
                }
              }
            });
          } else if (currentGame.guesser && currentGame.guesser.id === playerId) {
            set({
              currentGame: {
                ...currentGame,
                guesser: {
                  ...currentGame.guesser,
                  coins: currentGame.guesser.coins + amount
                }
              }
            });
          }
        }
      },

      updateStats: (won, coinsEarned) => {
        const { playerStats, currentGame } = get();
        const updatedStats = {
          ...playerStats,
          totalGames: playerStats.totalGames + 1,
          totalWins: won ? playerStats.totalWins + 1 : playerStats.totalWins,
          coinsWon: playerStats.coinsWon + (won ? coinsEarned : 0),
          favoriteWords: currentGame ? [...playerStats.favoriteWords, currentGame.currentWord].slice(-10) : playerStats.favoriteWords
        };
        set({ playerStats: updatedStats });
      },

      loadGame: (gameId) => {
        const { gameHistory } = get();
        return gameHistory.find(game => game.id === gameId) || null;
      },

      saveToHistory: (game) => {
        const { gameHistory } = get();
        set({ gameHistory: [...gameHistory, game].slice(-50) });
      }
    }),
    {
      name: 'pictionary-game-storage',
      storage: createJSONStorage(() => localStorage)
    }
  )
);

export default useGameStore;