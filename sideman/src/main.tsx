import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '@fontsource-variable/geist';
import '@fontsource-variable/geist-mono';
import './ui/styles.css';
import { App } from './ui/App';
import { useApp } from './ui/store';
import { player } from './audio/player';

// handles for poking at the app from the console while developing
if (import.meta.env.DEV) (window as unknown as { __sideman: unknown }).__sideman = { useApp, player };

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
