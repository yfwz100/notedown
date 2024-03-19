function createNativeProxy<T extends Record<string, unknown>>(name: string) {
  return new Proxy({} as T, {
    get(_, key) {
      return function (...args: unknown[]) {
        return window.webkit?.messageHandlers[name].postMessage({
          func: key,
          args,
        });
      };
    },
  });
}

export const native = createNativeProxy<{
  selectFile(): Promise<string>;
  syncState(state: { content: string; canUndo: boolean; canRedo: boolean }): Promise<void>;
  syncScrolled(scrolled: boolean): void;
}>('editor');