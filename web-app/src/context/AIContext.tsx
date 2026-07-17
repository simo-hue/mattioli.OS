import React, { createContext, useContext, useState, ReactNode } from "react";

interface AIContextType {
    isAIEnabled: boolean;
    setIsAIEnabled: (value: boolean) => void;
    toggleAI: () => void;
}

const AIContext = createContext<AIContextType | undefined>(undefined);

export const AIProvider = ({ children }: { children: ReactNode }) => {
    const [isAIEnabled, setIsAIEnabled] = useState(false); // Default: AI disabilitata

    const toggleAI = () => {
        setIsAIEnabled((prev) => !prev);
    };

    return (
        <AIContext.Provider value={{ isAIEnabled, setIsAIEnabled, toggleAI }}>
            {children}
        </AIContext.Provider>
    );
};

export const useAI = () => {
    const context = useContext(AIContext);
    if (context === undefined) {
        throw new Error("useAI must be used within an AIProvider");
    }
    return context;
};
