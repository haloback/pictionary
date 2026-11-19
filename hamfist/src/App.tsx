import { AnimatePresence, motion } from "motion/react";
import { useEffect } from "react";
import { useApp } from "./app/store";
import { GenreBrowser } from "./ui/GenreBrowser";
import { LayerRack } from "./ui/LayerRack";
import { Stage } from "./ui/Stage";
import { TopBar } from "./ui/TopBar";

function Toast() {
  const toast = useApp((s) => s.toast);
  const set = useApp((s) => s.set);
  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(() => set({ toast: null }), 3200);
    return () => clearTimeout(id);
  }, [toast, set]);
  return (
    <AnimatePresence>
      {toast && (
        <motion.div
          role="status"
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: 8 }}
          transition={{ type: "spring", stiffness: 380, damping: 30 }}
          className="fixed bottom-5 left-1/2 z-30 -translate-x-1/2 rounded-ctl bg-ink px-3.5 py-2 text-[12.5px] font-medium text-bg"
          style={{ boxShadow: "var(--shadow)" }}
        >
          {toast}
        </motion.div>
      )}
    </AnimatePresence>
  );
}

export function App() {
  return (
    <div className="flex h-dvh flex-col bg-bg text-ink max-lg:h-auto max-lg:min-h-dvh">
      <div className="max-lg:overflow-x-auto">
        <TopBar />
      </div>
      {/* Three panes on desktop; one column, stage first, on narrow windows. */}
      <main className="grid min-h-0 flex-1 grid-cols-1 lg:grid-cols-[264px_minmax(0,1fr)_336px]">
        <div className="contents max-lg:[&>*:first-child]:order-2">
          <GenreBrowser />
          <Stage />
          <LayerRack />
        </div>
      </main>
      <Toast />
    </div>
  );
}
