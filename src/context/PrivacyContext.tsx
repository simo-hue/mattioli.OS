
import React, { createContext, useContext, useState, ReactNode } from "react";

interface PrivacyContextType {
    isPrivacyMode: boolean;
    setIsPrivacyMode: (value: boolean) => void;
    togglePrivacyMode: () => void;
}

const PrivacyContext = createContext<PrivacyContextType | undefined>(undefined);

export const PrivacyProvider = ({ children }: { children: ReactNode }) => {
    const [isPrivacyMode, setIsPrivacyMode] = useState(false);

    const togglePrivacyMode = () => {
        setIsPrivacyMode((prev) => !prev);
    };

    return (
        <PrivacyContext.Provider value={{ isPrivacyMode, setIsPrivacyMode, togglePrivacyMode }}>
            {children}
        </PrivacyContext.Provider>
    );
};

export const usePrivacy = () => {
    const context = useContext(PrivacyContext);
    if (context === undefined) {
        throw new Error("usePrivacy must be used within a PrivacyProvider");
    }
    return context;
};
