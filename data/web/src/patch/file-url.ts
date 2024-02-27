function patch(o: any, key: string, replacement: (p?: PropertyDescriptor) => PropertyDescriptor) {
  const p = Object.getOwnPropertyDescriptor(o, key);
  Object.defineProperty(o, key, replacement(p));
}

export function normalizeImageUrl() {
  patch(Image.prototype, 'src', (p) => ({
    set(v) {
      console.log('image', v);
      if (typeof v === 'string' && v.startsWith('file://')) {
        v = v.replace('file://', 'local://');
      }
      p?.set?.call(this, v);
    },
    get() {
      return p?.get?.call(this);
    },
  }));
}