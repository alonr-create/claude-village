import { defineConfig } from 'vite';

export default defineConfig({
  base: '/',
  build: {
    outDir: '../VillageServer/public',
    emptyOutDir: false, // Preserve existing icons/ and village-ambient.mp3
    rollupOptions: {
      output: {
        assetFileNames: 'assets/[name]-[hash][extname]',
        chunkFileNames: 'assets/[name]-[hash].js',
        entryFileNames: 'assets/[name]-[hash].js',
      },
    },
  },
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:8420',
      '/ws': { target: 'ws://localhost:8420', ws: true },
      '/icons': 'http://localhost:8420',
      '/village-ambient.mp3': 'http://localhost:8420',
    },
  },
});
