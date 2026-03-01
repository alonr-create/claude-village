// World geometry
export const WORLD_SIZE = 3500;
export const POLL_INTERVAL = 500;
export const UI_THROTTLE = 1000;

// Isometric tilemap config
export const ISO_TILE_W = 128;
export const ISO_TILE_H = 64;
export const TILE_SIZE = 64;  // legacy — kept for icon grid
export const TERRAIN_COLS = 8; // tiles per row in spritesheet
export const TERRAIN_ROWS = 4; // rows in spritesheet

// Farm building type mapping (roofColor dominant channel → farm building)
export const FARM_BUILDING_MAP: Record<string, string> = {
  red: 'barn-red-iso',
  blue: 'farmhouse-blue-iso',
  green: 'silo-green-iso',
  brown: 'windmill-brown-iso',
};

// Farm decoration types for procedural placement
export const FARM_TREE_TEXTURES = [
  'tree-apple-iso', 'tree-oak-iso', 'tree-pine-iso', 'tree-cherry-iso', 'tree-autumn-iso',
];
export const FARM_DECO_TEXTURES = [
  'bush-iso', 'rock-iso', 'fence-iso', 'haystack-iso',
  'scarecrow-iso', 'water-well-iso', 'flowerbed-iso',
];

// Turkish foods
export const FOODS = [
  { emoji: '🥙', icon: 'doner', name: 'דונר' },
  { emoji: '🍖', icon: 'iskender', name: 'איסקנדר' },
  { emoji: '🥟', icon: 'manti', name: 'מנטי' },
  { emoji: '🫓', icon: 'lahmacun', name: 'לחמג׳ון' },
  { emoji: '🍢', icon: 'shish-kebab', name: 'שיש קבב' },
  { emoji: '🧆', icon: 'kofta', name: 'כופתה' },
  { emoji: '🫕', icon: 'pide', name: 'פידה' },
  { emoji: '🍚', icon: 'pilaf', name: 'פילאף' },
  { emoji: '🍬', icon: 'baklava', name: 'באקלווה' },
  { emoji: '🫖', icon: 'chai', name: 'צ׳אי' },
  { emoji: '☕', icon: 'turkish-coffee', name: 'קפה טורקי' },
];

// Icon fallback emojis (used when PNG icons are not available)
export const ICON_FALLBACK: Record<string, string> = {
  'crab': '🦀', 'house': '🏠', 'compass': '🧭', 'palm-tree': '🌴',
  'computer': '💻', 'megaphone': '📣', 'sunrise': '🌅', 'gamepad': '🎮',
  'clipboard': '📋', 'scroll': '📜', 'dice': '🎲',
  'sound-on': '🔊', 'sound-off': '🔇', 'approve': '✅', 'deny': '❌',
  'lightning': '⚡', 'mobile': '📱', 'hammer': '🔨',
  'doner': '🥙', 'iskender': '🍖', 'manti': '🥟', 'lahmacun': '🫓',
  'shish-kebab': '🍢', 'kofta': '🧆', 'pide': '🫕', 'pilaf': '🍚',
  'baklava': '🍬', 'chai': '🫖', 'turkish-coffee': '☕',
  'sign': '🪧', 'bench': '🪑', 'garden': '🌸', 'lantern': '🏮',
  'construction': '🏗', 'bridge': '🌉', 'fountain': '⛲', 'path': '🛤',
  'notice-board': '📌', 'computer-screen': '🖥', 'bug': '🐛',
  'mood-happy': '😊', 'mood-content': '🙂', 'mood-bored': '😐',
  'mood-hungry': '🤤', 'mood-social': '🗣', 'mood-creative': '🎨',
  'mood-tired': '😴', 'mood-excited': '🤩',
  'state-work': '💻', 'state-build': '🔨', 'state-eat': '🍽',
  'state-sleep': '💤', 'state-socialize': '💬', 'state-explore': '🚶',
  'state-request': '📋',
  'dawn': '🌅', 'day': '☀️', 'sunset': '🌇', 'evening': '🌆', 'night': '🌙',
  'sparkle': '✨', 'celebration': '🎉', 'wave': '👋',
  'req-food': '🥙', 'req-build': '🔨', 'req-tool': '🔧',
  'req-vacation': '🏖', 'req-raise': '💰', 'req-general': '📋',
  'need-hunger': '🍽', 'need-social': '💬', 'need-creativity': '🎨',
  'need-work': '💼', 'need-rest': '💤',
};

// Need bar colors
export const NEED_COLORS: Record<string, number> = {
  hunger: 0xff6b6b,
  social: 0x4ecdc4,
  creativity: 0xa855f7,
  workDrive: 0xf59e0b,
  rest: 0x60a5fa,
};

export const NEED_COLORS_HEX: Record<string, string> = {
  hunger: '#ff6b6b',
  social: '#4ecdc4',
  creativity: '#a855f7',
  workDrive: '#f59e0b',
  rest: '#60a5fa',
};

// Tree positions spread across the huge map
export const TREE_POSITIONS: [number, number][] = [
  // Inner ring (~1000)
  [-800, 200], [750, -150], [200, 900], [-100, -850],
  [-600, 600], [650, -550], [600, 700], [-500, -600],
  // Mid ring (~2000)
  [-1800, 500], [1700, 400], [500, -1800], [-400, 1700],
  [-1500, 1200], [1400, -1300], [1200, 1500], [-1300, -1400],
  [-2000, -200], [1900, -800], [800, 2000], [-700, -1900],
  // Outer ring (~3000-4000)
  [-3200, 500], [3100, -400], [500, 3300], [-300, -3100],
  [-2700, 2700], [2600, -2600], [2700, 2700], [-2600, -2600],
  [-3800, 1800], [3800, 1500], [1500, -3800], [-1500, 3800],
  // Scattered far
  [-4200, 100], [4300, -200], [100, 4400], [-200, -4200],
  [-3500, -3000], [3600, 3100], [-3000, 3500], [3100, -3600],
];

// Structure type → icon name mapping
export const STRUCT_ICON_MAP: Record<string, string> = {
  'שלט': 'sign', 'ספסל': 'bench', 'גן פרחים': 'garden',
  'פנס': 'lantern', 'גדר': 'construction', 'גשר': 'bridge',
  'באר': 'fountain', 'דרך': 'path', 'לוח מודעות': 'notice-board',
  'מבנה': 'house',
};

// House emoji → icon mapping
export const HOUSE_EMOJI_TO_ICON: Record<string, string> = {
  '🧭': 'compass', '🌴': 'palm-tree', '💻': 'computer',
  '📣': 'megaphone', '🌅': 'sunrise', '🎮': 'gamepad',
};

// Food emoji → icon mapping
export const FOOD_EMOJI_TO_ICON: Record<string, string> = {
  '🥙': 'doner', '🍖': 'iskender', '🥟': 'manti', '🫓': 'lahmacun',
  '🍢': 'shish-kebab', '🧆': 'kofta', '🫕': 'pide', '🍚': 'pilaf',
  '🍬': 'baklava', '🫖': 'chai', '☕': 'turkish-coffee',
};

// Mood emoji → icon mapping
export const MOOD_EMOJI_TO_ICON: Record<string, string> = {
  '😊': 'mood-happy', '🙂': 'mood-content', '😐': 'mood-bored',
  '🤤': 'mood-hungry', '🗣️': 'mood-social', '🗣': 'mood-social',
  '🎨': 'mood-creative', '😴': 'mood-tired', '🤩': 'mood-excited',
};

// State labels (Hebrew)
export const STATE_LABELS: Record<string, string> = {
  idle: 'ממתין', eat: 'אוכל', eating: 'אוכל',
  socialize: 'מדבר', work: 'עובד', build: 'בונה',
  rest: 'נח', explore: 'מטייל', request: 'מבקש',
};

// Need metadata
export const NEED_META: Record<string, { icon: string; label: string; color: string }> = {
  hunger: { icon: 'need-hunger', label: 'רעב', color: '#ff6b6b' },
  social: { icon: 'need-social', label: 'חברתי', color: '#4ecdc4' },
  creativity: { icon: 'need-creativity', label: 'יצירתי', color: '#a855f7' },
  workDrive: { icon: 'need-work', label: 'עבודה', color: '#f59e0b' },
  rest: { icon: 'need-rest', label: 'מנוחה', color: '#60a5fa' },
};

// Day period colors — bright FarmVille farm palette
export const DAY_COLORS: Record<string, { bg: number; overlayAlpha: number; overlayColor: number }> = {
  morning: { bg: 0x87CEEB, overlayAlpha: 0.05, overlayColor: 0xffd080 },   // bright sunrise sky
  day: { bg: 0x87CEEB, overlayAlpha: 0.03, overlayColor: 0xfffff0 },       // clear blue sky
  evening: { bg: 0x4a6080, overlayAlpha: 0.10, overlayColor: 0xff8040 },    // warm harvest sunset
  night: { bg: 0x0a1830, overlayAlpha: 0.15, overlayColor: 0x001040 },      // starry farm night
};

// Period display labels
export const PERIOD_LABELS: Record<string, string> = {
  morning: '🌅 בוקר',
  day: '☀️ יום',
  evening: '🌆 ערב',
  night: '🌙 לילה',
};

// All icon names to preload
export const ICON_NAMES = [
  'crab', 'house', 'compass', 'palm-tree', 'computer', 'megaphone',
  'sunrise', 'gamepad', 'clipboard', 'scroll', 'dice',
  'sound-on', 'sound-off', 'approve', 'deny', 'lightning', 'mobile', 'hammer',
  'doner', 'iskender', 'manti', 'lahmacun', 'shish-kebab', 'kofta',
  'pide', 'pilaf', 'baklava', 'chai', 'turkish-coffee',
  'sign', 'bench', 'garden', 'lantern', 'construction', 'bridge',
  'fountain', 'path', 'notice-board', 'computer-screen', 'bug',
  'mood-happy', 'mood-content', 'mood-bored', 'mood-hungry',
  'mood-social', 'mood-creative', 'mood-tired', 'mood-excited',
  'state-work', 'state-build', 'state-eat', 'state-sleep',
  'state-socialize', 'state-explore', 'state-request',
  'dawn', 'day', 'sunset', 'evening', 'night',
  'sparkle', 'celebration', 'wave',
  'req-food', 'req-build', 'req-tool', 'req-vacation', 'req-raise', 'req-general',
  'need-hunger', 'need-social', 'need-creativity', 'need-work', 'need-rest',
];
