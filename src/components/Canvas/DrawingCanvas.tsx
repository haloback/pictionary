import React, { useRef, useState, useEffect, useCallback, MouseEvent, TouchEvent } from 'react';
import { Path, Point, DrawingData } from '../../types/game';
import './DrawingCanvas.css';

interface DrawingCanvasProps {
  onDrawingComplete?: (drawing: DrawingData) => void;
  readOnly?: boolean;
  drawingData?: DrawingData;
}

export const DrawingCanvas: React.FC<DrawingCanvasProps> = ({ 
  onDrawingComplete, 
  readOnly = false,
  drawingData 
}) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [isDrawing, setIsDrawing] = useState(false);
  const [currentPath, setCurrentPath] = useState<Path | null>(null);
  const [paths, setPaths] = useState<Path[]>([]);
  const [currentColor, setCurrentColor] = useState('#000000');
  const [currentBrushSize, setBrushSize] = useState(5);
  const [canvasSize, setCanvasSize] = useState({ width: 800, height: 600 });

  const colors = ['#000000', '#0066CC', '#CC0000', '#00CC00', '#FFCC00', '#9900CC'];
  const brushSizes = [
    { label: 'Thin', size: 3 },
    { label: 'Medium', size: 5 },
    { label: 'Thick', size: 10 }
  ];

  const redrawCanvas = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    paths.forEach(path => {
      ctx.strokeStyle = path.color;
      ctx.lineWidth = path.brushSize;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';

      ctx.beginPath();
      path.points.forEach((point, index) => {
        if (index === 0) {
          ctx.moveTo(point.x, point.y);
        } else {
          ctx.lineTo(point.x, point.y);
        }
      });
      ctx.stroke();
    });

    if (currentPath) {
      ctx.strokeStyle = currentPath.color;
      ctx.lineWidth = currentPath.brushSize;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';

      ctx.beginPath();
      currentPath.points.forEach((point, index) => {
        if (index === 0) {
          ctx.moveTo(point.x, point.y);
        } else {
          ctx.lineTo(point.x, point.y);
        }
      });
      ctx.stroke();
    }
  }, [paths, currentPath]);

  useEffect(() => {
    const handleResize = () => {
      const canvas = canvasRef.current;
      if (canvas) {
        const container = canvas.parentElement;
        if (container) {
          const { width, height } = container.getBoundingClientRect();
          setCanvasSize({ width: width - 20, height: height - 20 });
        }
      }
    };

    handleResize();
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  useEffect(() => {
    if (drawingData && readOnly) {
      setPaths(drawingData.paths);
    }
  }, [drawingData, readOnly]);

  useEffect(() => {
    redrawCanvas();
  }, [redrawCanvas]);

  const getCoordinates = (e: MouseEvent | TouchEvent): Point | null => {
    const canvas = canvasRef.current;
    if (!canvas) return null;

    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width;
    const scaleY = canvas.height / rect.height;

    if ('touches' in e) {
      const touch = e.touches[0];
      return {
        x: (touch.clientX - rect.left) * scaleX,
        y: (touch.clientY - rect.top) * scaleY
      };
    } else {
      return {
        x: (e.clientX - rect.left) * scaleX,
        y: (e.clientY - rect.top) * scaleY
      };
    }
  };

  const startDrawing = (e: MouseEvent | TouchEvent) => {
    if (readOnly) return;
    
    const point = getCoordinates(e);
    if (!point) return;

    setIsDrawing(true);
    setCurrentPath({
      points: [point],
      color: currentColor,
      brushSize: currentBrushSize
    });
  };

  const draw = (e: MouseEvent | TouchEvent) => {
    if (!isDrawing || readOnly) return;

    const point = getCoordinates(e);
    if (!point || !currentPath) return;

    setCurrentPath({
      ...currentPath,
      points: [...currentPath.points, point]
    });
  };

  const stopDrawing = () => {
    if (!isDrawing || !currentPath) return;

    setIsDrawing(false);
    setPaths([...paths, currentPath]);
    setCurrentPath(null);
  };

  const clearCanvas = () => {
    setPaths([]);
    setCurrentPath(null);
  };

  const undo = () => {
    if (paths.length > 0) {
      setPaths(paths.slice(0, -1));
    }
  };

  const submitDrawing = () => {
    if (onDrawingComplete) {
      const drawingData: DrawingData = {
        paths,
        width: canvasSize.width,
        height: canvasSize.height
      };
      onDrawingComplete(drawingData);
    }
  };

  return (
    <div className="drawing-canvas-container">
      <div className="canvas-wrapper">
        <canvas
          ref={canvasRef}
          width={canvasSize.width}
          height={canvasSize.height}
          className="drawing-canvas"
          onMouseDown={startDrawing}
          onMouseMove={draw}
          onMouseUp={stopDrawing}
          onMouseLeave={stopDrawing}
          onTouchStart={startDrawing}
          onTouchMove={draw}
          onTouchEnd={stopDrawing}
        />
      </div>
      
      {!readOnly && (
        <div className="drawing-controls">
          <div className="color-palette">
            {colors.map(color => (
              <button
                key={color}
                className={`color-button ${currentColor === color ? 'selected' : ''}`}
                style={{ backgroundColor: color }}
                onClick={() => setCurrentColor(color)}
                aria-label={`Select ${color} color`}
              />
            ))}
          </div>
          
          <div className="brush-sizes">
            {brushSizes.map(({ label, size }) => (
              <button
                key={size}
                className={`brush-button ${currentBrushSize === size ? 'selected' : ''}`}
                onClick={() => setBrushSize(size)}
              >
                <span className="brush-preview" style={{ 
                  width: size * 2, 
                  height: size * 2,
                  backgroundColor: currentColor 
                }} />
                {label}
              </button>
            ))}
          </div>
          
          <div className="canvas-actions">
            <button className="action-button undo" onClick={undo}>
              Undo
            </button>
            <button className="action-button clear" onClick={clearCanvas}>
              Clear
            </button>
            <button className="action-button submit" onClick={submitDrawing}>
              Submit Drawing
            </button>
          </div>
        </div>
      )}
    </div>
  );
};