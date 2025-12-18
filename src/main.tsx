import { createRoot } from "react-dom/client";

import App from "./App.tsx";
import "./index.css";

try {
    const rootElement = document.getElementById("root");
    if (!rootElement) throw new Error("Root element not found");

    const root = createRoot(rootElement);
    root.render(<App />);
} catch (error) {
    console.error("Error in main.tsx:", error);
}
