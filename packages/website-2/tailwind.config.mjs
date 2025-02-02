import { theme } from "./panfactum-theme.mjs";

/** @type {import('tailwindcss').Config} */
export default {
  content: ["./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}"],
  safelist: [
    "pl-xl",
    "pl-2xl",
    "pl-3xl",
    "pl-4xl",
    "pl-5xl",
    "pl-6xl",
    "overflow-x-scroll",
    "text-white",
    "bg-primary",
    "bg-secondary",
    "bg-brand-primary",
    "bg-brand-primary-darker",
    "bg-brand-overlay",
  ],
  theme: {
    colors: {
      black: "#000",
      white: "#fff",
      offWhite: "#ededed",
      primary: {
        DEFAULT: "black",
      },
      "brand-primary": "var(--colors-background-bg-brand-primary)",
      "brand-primary-darker":
        "var(--colors-background-bg-brand-primary-darker)",
      gradientBorder: `linear-gradient(180deg, rgba(255, 255, 255, 0.12) 0%, rgba(255, 255, 255, 0) 100%)`,
      "offset-secondary": "var(--colors-brand-600, #2f688e)",
    },
    extend: {
      maxWidth: {
        xl: "768px",
        "2xl": "1024px",
        "3xl": "1280px",
        "4xl": "1536px",
      },
      minWidth: {
        sm: "480px",
      },

      screens: {},

      borderRadius: {
        lg: "10px",
        md: "8px",
        sm: "6px",
      },
      colors: {
        ...theme.colors,
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        border: "hsl(var(--border))",
        sidebar: {
          DEFAULT: "hsl(var(--sidebar-background))",
          foreground: "hsl(var(--sidebar-foreground))",
          primary: "hsl(var(--sidebar-primary))",
          "primary-foreground": "hsl(var(--sidebar-primary-foreground))",
          accent: "hsl(var(--sidebar-accent))",
          "accent-foreground": "hsl(var(--sidebar-accent-foreground))",
          border: "hsl(var(--sidebar-border))",
          ring: "hsl(var(--sidebar-ring))",
        },
        "brand-overlay": "hsl(var(--colors-background-bg-overlay))",
      },
      spacing: {
        none: "0px",
        xxs: "2px",
        xs: "4px",
        sm: "6px",
        md: "8px",
        lg: "12px",
        xl: "16px",
        "2xl": "20px",
        "3xl": "24px",
        "4xl": "32px",
        "5xl": "40px",
        "6xl": "48px",
        "7xl": "64px",
        "8xl": "80px",
        "9xl": "96px",
        "10xl": "128px",
        "11xl": "160px",
        "container-padding-mobile": "16px",
        "container-padding-desktop": "32px",
        "container-max-width-desktop": "1280px",
      },
      fontFamily: {
        inter: ["Inter", "sans-serif"],
        machina: ["neue-machina", "sans-serif"],
        montreal: ["neue-montreal-mono", "monospace"],
      },
      fontSize: {
        "display-2xl": "72px",
        "display-xl": "60px",
        "display-lg": "48px",
        "display-md": "36px",
        "display-sm": "30px",
        "display-xs": "24px",
        xl: "20px",
        lg: "18px",
        md: "16px",
        sm: "14px",
        xs: "12px",
      },
      backgroundImage: {
        "hero-pattern": "url('/hero-pattern.svg')",
      },
      keyframes: {
        "accordion-down": {
          from: {
            height: "0",
          },
          to: {
            height: "var(--radix-accordion-content-height)",
          },
        },
        "accordion-up": {
          from: {
            height: "var(--radix-accordion-content-height)",
          },
          to: {
            height: "0",
          },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
      },
      zIndex: {
        "top-navigation": 400,
        "top-navigation-mobile-menu": 405,
        "content-fixed-navigation": 407,
        "fixed-side-panel": 410,
        drawer: 500,
      },
    },
  },
  plugins: [
    require("tailwindcss-animate"),
    require("@tailwindcss/typography"),
    function ({ addUtilities }) {
      addUtilities({
        ".bg-brand-primary": {
          backgroundColor: "var(--colors-background-bg-brand-primary)",
        },
      });
    },
  ],
};
