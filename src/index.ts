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
 * - Zero polling when idle (no battery drain)
 * - Fast polling (50ms) only during dimension changes for smooth transitions
 * - Trusts that rotations trigger dimension change events
 */
export function useInsets(): Insets {
  const [insets, setInsets] = useState<Insets>(getInsets);

  useEffect(() => {
    let pollingId: ReturnType<typeof setInterval> | null = null;
    let stabilizeTimeout: ReturnType<typeof setTimeout> | null = null;
    let lastInsets = getInsets();

    const updateInsets = () => {
      const newInsets = getInsets();
      if (lastInsets.top !== newInsets.top || lastInsets.bottom !== newInsets.bottom ||
          lastInsets.left !== newInsets.left || lastInsets.right !== newInsets.right) {
        lastInsets = newInsets;
        setInsets(newInsets);
      }
    };

    const stopPolling = () => {
      if (pollingId) {
        clearInterval(pollingId);
        pollingId = null;
      }
      if (stabilizeTimeout) {
        clearTimeout(stabilizeTimeout);
        stabilizeTimeout = null;
      }
      updateInsets(); // One final read
    };

    const startPolling = () => {
      // Already polling? Just extend timeout
      if (pollingId) {
        if (stabilizeTimeout) clearTimeout(stabilizeTimeout);
        stabilizeTimeout = setTimeout(stopPolling, 800);
        return;
      }

      // Poll at 50ms during rotation, stop after 800ms of stability
      pollingId = setInterval(updateInsets, 50);
      stabilizeTimeout = setTimeout(stopPolling, 800);
    };

    // Only poll when dimensions actually change
    const subscription = Dimensions.addEventListener('change', startPolling);

    return () => {
      stopPolling();
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
