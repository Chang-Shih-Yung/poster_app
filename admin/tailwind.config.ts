import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        bg: "#0d1116",
        surface: "#161b22",
        surfaceRaised: "#1f252d",
        line1: "#2a323c",
        line2: "#3b4552",
        text: "#e6edf3",
        textMute: "#8b949e",
        textFaint: "#6e7681",
        accent: "#58a6ff",
      },
      fontFamily: {
        sans: ["-apple-system", "BlinkMacSystemFont", "Segoe UI", "Roboto", "Helvetica", "Arial", "Noto Sans TC", "sans-serif"],
      },
    },
  },
  plugins: [],
};

export default config;
