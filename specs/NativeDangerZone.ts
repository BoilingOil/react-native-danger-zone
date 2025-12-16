import { TurboModule, TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  readonly getInsets: () => {
    top: number;
    bottom: number;
    left: number;
    right: number;
  };
}

export default TurboModuleRegistry.getEnforcing<Spec>('NativeDangerZone');
