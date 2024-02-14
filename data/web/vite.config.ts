import { defineConfig } from 'vite';
import { resolve } from 'node:path';

export default defineConfig({
  base: './',
  build: {
    outDir: resolve(__dirname, '..', '..', 'builddir', 'data', 'web'),
  }
});