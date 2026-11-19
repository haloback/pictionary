import "@fontsource-variable/geist";
import "@fontsource-variable/geist-mono";
import { MotionConfig } from "motion/react";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import { boot } from "./app/controller";
import "./index.css";

if (window.hamfist?.platform === "darwin") document.documentElement.classList.add("mac-app");
boot();

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <MotionConfig reducedMotion="user">
      <App />
    </MotionConfig>
  </StrictMode>,
);
