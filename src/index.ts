import { useEffect, useState } from 'react';
import { Dimensions } from 'react-native';
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
 * For reactive updates on rotation, use useInsets() hook instead.
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
 * Hook that returns insets and auto-updates on orientation change.
 * This is the recommended way to use DangerZone.
 */
export function useInsets(): Insets {
  const [insets, setInsets] = useState<Insets>(getInsets);

  useEffect(() => {
    const update = () => {
      setInsets(getInsets());
    };

    const subscription = Dimensions.addEventListener('change', update);

    return () => {
      subscription.remove();
    };
  }, []);

  return insets;
}

/**
 * Cached insets - call once at app start, use everywhere.
 * Note: Does NOT update on rotation. Use useInsets() for that.
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
  useInsets,
  getCachedInsets,
  clearCache,
};
