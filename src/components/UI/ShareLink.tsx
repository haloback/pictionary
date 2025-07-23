import React, { useState } from 'react';
import { motion } from 'framer-motion';
import './ShareLink.css';

interface ShareLinkProps {
  shareUrl: string;
  onContinue?: () => void;
}

export const ShareLink: React.FC<ShareLinkProps> = ({ shareUrl, onContinue }) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(shareUrl);
      setCopied(true);
      setTimeout(() => setCopied(false), 3000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  };

  return (
    <motion.div 
      className="share-link-container"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
    >
      <div className="share-link-card">
        <h2>🎨 Drawing Complete!</h2>
        <p>Share this link with your friend to let them guess your drawing:</p>
        
        <div className="link-box">
          <input 
            type="text" 
            value={shareUrl} 
            readOnly 
            className="link-input"
            onClick={(e) => e.currentTarget.select()}
          />
          <motion.button 
            className={`copy-button ${copied ? 'copied' : ''}`}
            onClick={handleCopy}
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
          >
            {copied ? '✓ Copied!' : '📋 Copy'}
          </motion.button>
        </div>

        <div className="share-options">
          <motion.button 
            className="share-button whatsapp"
            onClick={() => window.open(`https://wa.me/?text=${encodeURIComponent(`Can you guess my drawing? ${shareUrl}`)}`, '_blank')}
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
          >
            Share on WhatsApp
          </motion.button>
          
          <motion.button 
            className="share-button email"
            onClick={() => window.open(`mailto:?subject=Guess my Pictionary drawing!&body=${encodeURIComponent(`I drew something for you! Can you guess what it is?\n\n${shareUrl}`)}`, '_blank')}
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
          >
            Share via Email
          </motion.button>
        </div>

        {onContinue && (
          <motion.button 
            className="continue-button"
            onClick={onContinue}
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
          >
            Back to Home
          </motion.button>
        )}
      </div>
    </motion.div>
  );
};