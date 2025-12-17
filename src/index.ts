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
 * - Fast polling (50ms) during dimension changes for smooth transitions
 * - Slow polling (500ms) in landscape to catch left<->right flips
 * - No polling in portrait (no flips possible)
 */
export function useInsets(): Insets {
  const [insets, setInsets] = useState<Insets>(getInsets);

  useEffect(() => {
    let fastPollingId: ReturnType<typeof setInterval> | null = null;
    let slowPollingId: ReturnType<typeof setInterval> | null = null;
    let stabilizeTimeout: ReturnType<typeof setTimeout> | null = null;
    let lastInsets = getInsets();

    const isLandscape = () => {
      const { width, height } = Dimensions.get('window');
      return width > height;
    };

    const updateInsets = () => {
      const newInsets = getInsets();
      if (lastInsets.top !== newInsets.top || lastInsets.bottom !== newInsets.bottom ||
          lastInsets.left !== newInsets.left || lastInsets.right !== newInsets.right) {
        lastInsets = newInsets;
        setInsets(newInsets);
      }
    };

    const stopFastPolling = () => {
      if (fastPollingId) {
        clearInterval(fastPollingId);
        fastPollingId = null;
      }
      if (stabilizeTimeout) {
        clearTimeout(stabilizeTimeout);
        stabilizeTimeout = null;
      }
      updateInsets();
      // Start slow polling if in landscape
      startSlowPollingIfLandscape();
    };

    const startFastPolling = () => {
      // Stop slow polling during fast polling
      if (slowPollingId) {
        clearInterval(slowPollingId);
        slowPollingId = null;
      }

      // Already fast polling? Just extend timeout
      if (fastPollingId) {
        if (stabilizeTimeout) clearTimeout(stabilizeTimeout);
        stabilizeTimeout = setTimeout(stopFastPolling, 800);
        return;
      }

      fastPollingId = setInterval(updateInsets, 50);
      stabilizeTimeout = setTimeout(stopFastPolling, 800);
    };

    const startSlowPollingIfLandscape = () => {
      if (slowPollingId) return; // Already slow polling
      if (!isLandscape()) return; // Portrait - no need

      // Poll every 500ms in landscape to catch flips
      slowPollingId = setInterval(updateInsets, 500);
    };

    const stopSlowPolling = () => {
      if (slowPollingId) {
        clearInterval(slowPollingId);
        slowPollingId = null;
      }
    };

    // Start polling when dimensions change
    const subscription = Dimensions.addEventListener('change', () => {
      startFastPolling();
    });

    // Initial fetch and start slow polling if needed
    updateInsets();
    startSlowPollingIfLandscape();

    return () => {
      stopFastPolling();
      stopSlowPolling();
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
