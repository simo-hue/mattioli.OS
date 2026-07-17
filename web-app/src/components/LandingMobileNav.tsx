import { useState, useEffect } from "react";
import { createPortal } from "react-dom";
import { motion, AnimatePresence } from "framer-motion";
import { Menu, X, ArrowRight } from "lucide-react";
import { Link, useLocation } from "react-router-dom";
import { Button } from "@/components/ui/button";

const LandingMobileNav = () => {
    const [isOpen, setIsOpen] = useState(false);
    const location = useLocation();

    // Close menu when route changes
    useEffect(() => {
        setIsOpen(false);
    }, [location]);

    // Prevent body scroll when menu is open
    useEffect(() => {
        if (isOpen) {
            document.body.style.overflow = "hidden";
        } else {
            document.body.style.overflow = "unset";
        }
        return () => {
            document.body.style.overflow = "unset";
        };
    }, [isOpen]);

    const menuItems = [
        { path: "/features", label: "Features" },
        { path: "/philosophy", label: "Philosophy" },
        { path: "/tech", label: "Tech" },
        { path: "/creator", label: "The Founder" },
        { path: "/faq", label: "FAQ" },
    ];

    return (
        <div className="md:hidden">
            <Button
                variant="ghost"
                size="icon"
                className="relative z-[10000] text-white hover:bg-white/10"
                onClick={() => setIsOpen(!isOpen)}
            >
                {isOpen ? <X /> : <Menu />}
            </Button>

            {createPortal(
                <AnimatePresence>
                    {isOpen && (
                        <motion.div
                            initial={{ opacity: 0, x: "100%" }}
                            animate={{ opacity: 1, x: 0 }}
                            exit={{ opacity: 0, x: "100%" }}
                            transition={{ type: "spring", damping: 25, stiffness: 200 }}
                            className="fixed inset-0 z-[9999] bg-black/80 backdrop-blur-xl pt-24 px-6"
                        >
                            <Button
                                variant="ghost"
                                size="icon"
                                className="absolute top-4 right-6 text-white hover:bg-white/10"
                                onClick={() => setIsOpen(false)}
                            >
                                <X />
                            </Button>
                            <nav className="flex flex-col gap-6">
                                {menuItems.map((item, idx) => (
                                    <motion.div
                                        key={item.path}
                                        initial={{ opacity: 0, x: 20 }}
                                        animate={{ opacity: 1, x: 0 }}
                                        transition={{ delay: idx * 0.1 }}
                                    >
                                        <Link
                                            to={item.path}
                                            className="text-2xl font-medium text-white/80 hover:text-white flex items-center justify-between group py-2 border-b border-white/5"
                                        >
                                            {item.label}
                                            <ArrowRight size={20} className="opacity-0 group-hover:opacity-100 -translate-x-4 group-hover:translate-x-0 transition-all text-purple-400" />
                                        </Link>
                                    </motion.div>
                                ))}

                                <motion.div
                                    initial={{ opacity: 0, y: 20 }}
                                    animate={{ opacity: 1, y: 0 }}
                                    transition={{ delay: 0.5 }}
                                    className="mt-8 grid grid-cols-2 gap-4"
                                >
                                    <Link to="/get-started">
                                        <Button className="w-full h-12 text-sm md:text-lg rounded-xl bg-white text-black hover:bg-zinc-200">
                                            Guide
                                        </Button>
                                    </Link>
                                    <a href="https://github.com/simo-hue/mattioli.OS" target="_blank" rel="noreferrer">
                                        <Button className="w-full h-12 bg-white/10 border border-white/10 text-white hover:bg-white/20 rounded-xl px-8 text-sm md:text-lg">
                                            GitHub
                                        </Button>
                                    </a>
                                </motion.div>
                            </nav>
                        </motion.div>
                    )}
                </AnimatePresence>,
                document.body
            )}
        </div>
    );
};

export default LandingMobileNav;
