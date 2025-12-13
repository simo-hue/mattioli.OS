import { createRoot } from "react-dom/client";

import App from "./App.tsx";
import "./index.css";

console.log("Main.tsx executing...");
try {
    const rootElement = document.getElementById("root");
    console.log("Root element:", rootElement);
    if (!rootElement) throw new Error("Root element not found");

    const root = createRoot(rootElement);
    console.log("Root created, rendering App...");
    root.render(<App />);
    console.log("App rendered called");
} catch (error) {
    console.error("Error in main.tsx:", error);
}
