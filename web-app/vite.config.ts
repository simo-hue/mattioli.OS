import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import path from "path";


// https://vitejs.dev/config/
export default defineConfig(({ mode, isSsrBuild }) => ({
  base: "/mattioli.OS/",
  // vite-react-ssg reads its options from here, not from the ViteReactSSG() call.
  ssgOptions: {
    // Prerender only the public marketing pages. Everything under /sw sits behind
    // a Supabase session: rendering it in Node hits localStorage and other browser
    // APIs, and it would publish an empty redirect at a URL that must not be
    // indexed anyway. /auth is excluded for the same reason.
    includedRoutes: (paths: string[]) => {
      const keep = paths.filter(
        (p) => !p.replace(/^\//, "").startsWith("sw") && !p.includes("auth") && !p.includes("*"),
      );
      console.log("[ssg] prerendering:", JSON.stringify(keep));
      return keep;
    },
    formatting: "minify",
    // Emit faq/index.html rather than faq.html. The live URLs already carry a
    // trailing slash (/mattioli.OS/faq/) and are canonicalised that way, and
    // GitHub Pages resolves a trailing-slash URL to <dir>/index.html only.
    dirStyle: "nested",
  },
  server: {
    host: "::",
    port: 8080,
  },
  plugins: [react()].filter(Boolean),
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  build: {
    sourcemap: false,
    rollupOptions: {
      output: {
        // manualChunks applies to the CLIENT bundle only. During the SSR pass
        // vite-react-ssg marks react/react-dom external, and Rollup refuses to
        // put an external module into a manual chunk
        // (EXTERNAL_MODULES_CANNOT_BE_INCLUDED_IN_MANUAL_CHUNKS).
        manualChunks: isSsrBuild
          ? undefined
          : {
              vendor: ['react', 'react-dom', 'react-router-dom'],
              ui: ['@radix-ui/react-slot', 'class-variance-authority', 'clsx', 'tailwind-merge'],
            },
      },
    },
  },
}));
