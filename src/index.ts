import NativeDangerZone from '../specs/NativeDangerZone';

export interface Insets {
  top: number;
  bottom: number;
  left: number;
  right: number;
}

const ZERO_INSETS: Insets = { top: 0, bottom: 0, left: 0, right: 0 };

/**
 * Get safe area insets synchronously.
 * No provider, no events, no bullshit.
 */
export function getInsets(): Insets {
  try {
    return NativeDangerZone.getInsets();
  } catch (e) {
    if (__DEV__) {
      console.warn('react-native-danger-zone: Failed to get insets', e);
    }
    return ZERO_INSETS;
  }
}

/**
 * Cached insets - call once at app start, use everywhere.
 */
let cachedInsets: Insets | null = null;

export function getCachedInsets(): Insets {
  if (!cachedInsets) {
    cachedInsets = getInsets();
  }
  return cachedInsets;
}

/**
 * Clear cache to get fresh values (e.g., after rotation).
 */
export function clearCache(): void {
  cachedInsets = null;
}

export default {
  getInsets,
  getCachedInsets,
  clearCache,
};
