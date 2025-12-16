export interface Insets {
  top: number;
  bottom: number;
  left: number;
  right: number;
}

export function getInsets(): Insets;
export function useInsets(): Insets;
export function getCachedInsets(): Insets;
export function clearCache(): void;

declare const DangerZone: {
  getInsets: typeof getInsets;
  useInsets: typeof useInsets;
  getCachedInsets: typeof getCachedInsets;
  clearCache: typeof clearCache;
};

export default DangerZone;
