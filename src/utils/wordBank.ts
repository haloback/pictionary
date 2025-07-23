import { Difficulty } from '../types/game';

const easyWords = [
  'apple', 'ball', 'cat', 'dog', 'tree', 'house', 'car', 'book', 'chair', 'table',
  'phone', 'computer', 'bicycle', 'umbrella', 'sandwich', 'pizza', 'cake', 'flower',
  'sun', 'moon', 'star', 'cloud', 'rain', 'door', 'window', 'bed', 'lamp', 'clock',
  'pen', 'pencil', 'paper', 'scissors', 'key', 'lock', 'cup', 'bottle', 'hat', 'shoe',
  'shirt', 'pants', 'socks', 'glasses', 'watch', 'ring', 'bag', 'box', 'gift', 'balloon',
  'camera', 'guitar', 'piano', 'drum', 'microphone', 'television', 'radio', 'newspaper',
  'magazine', 'map', 'flag', 'coin', 'money', 'wallet', 'purse', 'backpack', 'suitcase',
  'airplane', 'train', 'bus', 'boat', 'ship', 'helicopter', 'rocket', 'bridge', 'road'
];

const mediumWords = [
  'lighthouse', 'telescope', 'microscope', 'compass', 'binoculars', 'typewriter',
  'calculator', 'projector', 'chandelier', 'fountain', 'statue', 'monument', 'castle',
  'pyramid', 'windmill', 'greenhouse', 'aquarium', 'terrarium', 'hourglass', 'pendulum',
  'metronome', 'thermometer', 'barometer', 'stethoscope', 'syringe', 'wheelchair',
  'crutches', 'bandage', 'trophy', 'medal', 'diploma', 'certificate', 'passport',
  'luggage', 'escalator', 'elevator', 'treadmill', 'dumbbell', 'basketball', 'football',
  'baseball', 'tennis racket', 'golf club', 'bowling ball', 'dartboard', 'chessboard',
  'dice', 'playing cards', 'puzzle', 'rubiks cube', 'yo-yo', 'kite', 'frisbee',
  'skateboard', 'roller skates', 'scooter', 'unicycle', 'pogo stick', 'trampoline',
  'swing', 'slide', 'seesaw', 'sandbox', 'jungle gym', 'merry-go-round'
];

const hardWords = [
  'accordion', 'bagpipes', 'xylophone', 'harmonica', 'tambourine', 'didgeridoo',
  'kaleidoscope', 'periscope', 'sextant', 'astrolabe', 'sundial', 'abacus',
  'guillotine', 'catapult', 'trebuchet', 'drawbridge', 'portcullis', 'gargoyle',
  'weathervane', 'scarecrow', 'totem pole', 'obelisk', 'sarcophagus', 'hieroglyphics',
  'boomerang', 'dreamcatcher', 'loom', 'spinning wheel', 'anvil', 'bellows',
  'cauldron', 'mortar and pestle', 'hourglass', 'pendulum clock', 'cuckoo clock',
  'grandfather clock', 'phonograph', 'gramophone', 'jukebox', 'slot machine',
  'pinball machine', 'arcade cabinet', 'joystick', 'steering wheel', 'gear shift',
  'carburetor', 'spark plug', 'alternator', 'radiator', 'muffler', 'catalytic converter',
  'transmission', 'differential', 'suspension', 'shock absorber', 'brake pad',
  'windshield wiper', 'rearview mirror', 'speedometer', 'odometer', 'tachometer'
];

export const wordBank = {
  easy: easyWords,
  medium: mediumWords,
  hard: hardWords
};

export const getRandomWord = (difficulty: Difficulty): string => {
  const words = wordBank[difficulty];
  return words[Math.floor(Math.random() * words.length)];
};

export const getAllWords = (): string[] => {
  return [...easyWords, ...mediumWords, ...hardWords];
};