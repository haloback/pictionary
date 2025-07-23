import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { HomePage } from './pages/HomePage';
import { DrawingPage } from './pages/DrawingPage';
import { GuessingPage } from './pages/GuessingPage';
import { GamePage } from './pages/GamePage';
import './App.css';

function App() {
  return (
    <Router>
      <div className="App">
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/draw" element={<DrawingPage />} />
          <Route path="/guess/:gameId" element={<GuessingPage />} />
          <Route path="/game/:gameId" element={<GamePage />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
