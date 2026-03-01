// World geometry
export const WORLD_SIZE = 600;
export const POLL_INTERVAL = 500;
export const UI_THROTTLE = 1000;

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

// Tree positions in the village
export const TREE_POSITIONS: [number, number][] = [
  [-320, 50], [310, -40], [50, 330], [-30, -310],
  [-270, 270], [260, -260], [270, 270], [-260, -260],
  [-380, 180], [380, 150], [150, -380], [-150, 380],
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

// Day period colors
export const DAY_COLORS: Record<string, { bg: number; overlayAlpha: number; overlayColor: number }> = {
  morning: { bg: 0x3a5a3a, overlayAlpha: 0, overlayColor: 0x000000 },
  day: { bg: 0x2a4a2a, overlayAlpha: 0, overlayColor: 0x000000 },
  evening: { bg: 0x2a3040, overlayAlpha: 0.25, overlayColor: 0x1a0a30 },
  night: { bg: 0x151e25, overlayAlpha: 0.4, overlayColor: 0x0a0a20 },
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
