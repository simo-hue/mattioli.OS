import { useState } from "react";
import type { LucideIcon } from "lucide-react";
import { faqData as FAQ_DATA } from "@/data/faq";
import { motion, AnimatePresence } from "framer-motion";
import {
    ChevronDown, Search, ArrowLeft, Shield, Brain,
    Database, Activity, Target, Smartphone, Code2
} from "lucide-react";
import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import LandingMobileNav from "@/components/LandingMobileNav";
import PublicHeader from "@/components/PublicHeader";
import PublicFooter from "@/components/PublicFooter";
import RouteHead from "@/components/RouteHead";

// FAQ Data
const FAQ_ICONS: Record<string, LucideIcon> = {
    "Philosophy & General": Activity,
    "Daily Protocol": Activity,
    "Macro Goals & Vision": Target,
    "AI Coach & Privacy": Brain,
    "Tech & Data": Database,
    "Troubleshooting & Support": Code2,
};

const faqData = FAQ_DATA.map((c) => ({ ...c, icon: FAQ_ICONS[c.category] }));


const FAQPage = () => {
    const [searchQuery, setSearchQuery] = useState("");
    const [openIndex, setOpenIndex] = useState<string | null>(null);
    const [activeCategory, setActiveCategory] = useState("All");

    const filteredFAQs = faqData.map(cat => ({
        ...cat,
        questions: cat.questions.filter(q =>
            q.q.toLowerCase().includes(searchQuery.toLowerCase()) ||
            q.a.toLowerCase().includes(searchQuery.toLowerCase())
        )
    })).filter(cat => cat.questions.length > 0 && (activeCategory === "All" || cat.category === activeCategory));

    const toggleAccordion = (id: string) => {
        setOpenIndex(openIndex === id ? null : id);
    };

    return (
        <div className="min-h-screen bg-black text-white selection:bg-purple-900 selection:text-white">
            <RouteHead route="faq" />
            {/* Nav */}
            {/* Nav */}
            <PublicHeader />

            {/* Hero & Search */}
            <section className="pt-32 pb-12 px-6 bg-zinc-900/20">
                <div className="container mx-auto max-w-4xl text-center">
                    <h1 className="text-4xl md:text-5xl font-bold mb-6 bg-gradient-to-br from-white to-zinc-500 bg-clip-text text-transparent">
                        Frequently Asked Questions
                    </h1>
                    <p className="text-zinc-400 mb-8 max-w-2xl mx-auto">
                        Everything you need to know about Mattioli.OS. From the core philosophy to the deepest technical details.
                    </p>

                    <div className="relative max-w-xl mx-auto">
                        <Search className="absolute left-4 top-3.5 h-5 w-5 text-zinc-500" />
                        <Input
                            type="text"
                            placeholder="Search for a question..."
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            className="pl-12 h-12 bg-white/5 border-white/10 rounded-full focus:ring-purple-500/50 text-lg"
                        />
                    </div>
                </div>
            </section>

            {/* Main Content */}
            <section className="py-12 px-6">
                <div className="container mx-auto max-w-4xl">

                    {/* Category Filter */}
                    <div className="flex flex-wrap gap-2 justify-center mb-12">
                        <Button
                            variant={activeCategory === "All" ? "secondary" : "ghost"}
                            onClick={() => setActiveCategory("All")}
                            className="rounded-full"
                        >
                            All
                        </Button>
                        {faqData.map((cat, i) => (
                            <Button
                                key={i}
                                variant={activeCategory === cat.category ? "secondary" : "ghost"}
                                onClick={() => setActiveCategory(cat.category)}
                                className="rounded-full border border-white/5"
                            >
                                {cat.category}
                            </Button>
                        ))}
                    </div>

                    {/* Questions List */}
                    <div className="space-y-12">
                        {filteredFAQs.map((category, catIndex) => (
                            <div key={catIndex} className="animate-in fade-in slide-in-from-bottom-4 duration-500">
                                <div className="flex items-center gap-3 mb-6 pb-2 border-b border-white/10">
                                    <category.icon className="text-purple-400" size={24} />
                                    <h2 className="text-2xl font-semibold">{category.category}</h2>
                                </div>

                                <div className="space-y-4">
                                    {category.questions.map((item, qIndex) => {
                                        const id = `${catIndex}-${qIndex}`;
                                        const isOpen = openIndex === id;

                                        return (
                                            <div
                                                key={qIndex}
                                                className={`rounded-xl border transition-all duration-200 ${isOpen ? "bg-white/5 border-purple-500/30" : "bg-transparent border-white/5 hover:bg-white/5"}`}
                                            >
                                                <button
                                                    onClick={() => toggleAccordion(id)}
                                                    className="w-full flex items-center justify-between p-5 text-left"
                                                >
                                                    <span className={`font-medium text-lg ${isOpen ? "text-purple-300" : "text-zinc-200"}`}>
                                                        {item.q}
                                                    </span>
                                                    <ChevronDown
                                                        className={`transform transition-transform duration-200 text-zinc-500 ${isOpen ? "rotate-180" : ""}`}
                                                    />
                                                </button>

                                                <AnimatePresence>
                                                    {isOpen && (
                                                        <motion.div
                                                            initial={{ height: 0, opacity: 0 }}
                                                            animate={{ height: "auto", opacity: 1 }}
                                                            exit={{ height: 0, opacity: 0 }}
                                                            className="overflow-hidden"
                                                        >
                                                            <div className="p-5 pt-0 text-zinc-400 leading-relaxed border-t border-white/5 mt-2">
                                                                {item.a}
                                                            </div>
                                                        </motion.div>
                                                    )}
                                                </AnimatePresence>
                                            </div>
                                        );
                                    })}
                                </div>
                            </div>
                        ))}

                        {filteredFAQs.length === 0 && (
                            <div className="text-center py-20 text-zinc-500">
                                <p>No questions found for "{searchQuery}"</p>
                                <Button variant="link" onClick={() => setSearchQuery("")} className="text-purple-400">Clear search</Button>
                            </div>
                        )}
                    </div>
                </div>
            </section>

            {/* Footer Call to Action */}
            <section className="py-20 border-t border-white/10 text-center">
                <h3 className="text-2xl font-bold mb-4">Have more questions?</h3>
                <p className="text-zinc-400 mb-8">
                    Join the community or contact us directly on GitHub.
                </p>
                <a href="https://github.com/simo-hue/mattioli.OS" target="_blank" rel="noreferrer">
                    <Button className="bg-white text-black hover:bg-zinc-200 rounded-full px-8 py-6 text-lg">
                        Go to GitHub
                    </Button>
                </a>
            </section>

            {/* Footer */}
            <PublicFooter />
        </div>
    );
};

export default FAQPage;
