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
 *
 * Polls every 200ms to catch landscape-left <-> landscape-right flips
 * (which don't trigger Dimensions change since width/height stay the same)
 */
export function useInsets(): Insets {
  const [insets, setInsets] = useState<Insets>(getInsets);

  useEffect(() => {
    const update = () => {
      const newInsets = getInsets();
      setInsets(prev => {
        // Only update if values actually changed
        if (prev.top !== newInsets.top || prev.bottom !== newInsets.bottom ||
            prev.left !== newInsets.left || prev.right !== newInsets.right) {
          return newInsets;
        }
        return prev;
      });
    };

    // Poll every 200ms to catch all rotations including landscape flips
    const intervalId = setInterval(update, 200);

    // Also check on dimension changes
    const subscription = Dimensions.addEventListener('change', update);

    return () => {
      clearInterval(intervalId);
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
