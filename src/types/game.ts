export type GameMode = 'bestOf' | 'wager';
export type GameStatus = 'waiting' | 'drawing' | 'guessing' | 'finished';
export type Difficulty = 'easy' | 'medium' | 'hard';

export interface Player {
  id: string;
  name: string;
  coins: number;
  wins: number;
  losses: number;
}

export interface DrawingData {
  paths: Path[];
  width: number;
  height: number;
}

export interface Path {
  points: Point[];
  color: string;
  brushSize: number;
}

export interface Point {
  x: number;
  y: number;
}

export interface Game {
  id: string;
  mode: GameMode;
  status: GameStatus;
  currentWord: string;
  difficulty: Difficulty;
  drawer: Player;
  guesser?: Player;
  drawing?: DrawingData;
  guesses: Guess[];
  roundsTotal?: number;
  currentRound: number;
  wagerAmount?: number;
  timeLimit: number;
  createdAt: number;
  shareUrl: string;
}

export interface Guess {
  word: string;
  isCorrect: boolean;
  timestamp: number;
}

export interface GameStats {
  totalWins: number;
  totalGames: number;
  coinsWon: number;
  favoriteWords: string[];
}