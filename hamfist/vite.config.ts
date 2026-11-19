import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  // Relative asset paths so the build loads from file:// inside the app bundle.
  base: "./",
  plugins: [react(), tailwindcss()],
  server: { port: 5173, strictPort: true },
  build: { outDir: "dist", chunkSizeWarningLimit: 1200 },
  test: { include: ["tests/**/*.test.ts"] },
});
