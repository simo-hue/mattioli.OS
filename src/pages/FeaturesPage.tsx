import { motion } from "framer-motion";
import {
    CheckCircle2, Target, Brain, BookOpen, FileText,
    Shield, Zap, Calendar, Activity, Lock, ArrowLeft,
    Smartphone, Database, Cloud, LifeBuoy
} from "lucide-react";
import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import PublicHeader from "@/components/PublicHeader";
import PublicFooter from "@/components/PublicFooter";

const FeaturesPage = () => {
    const fadeInUp = {
        initial: { opacity: 0, y: 20 },
        animate: { opacity: 1, y: 0 },
        transition: { duration: 0.5 }
    };

    const container = {
        animate: {
            transition: {
                staggerChildren: 0.1
            }
        }
    };

    const featureSections = [
        {
            title: "Daily Mastery",
            description: "The heart of the system. Surgical tracking of your routines.",
            icon: Activity,
            features: [
                { name: "Tri-State Logic", desc: "Not just done/not done. Manage 'Done', 'Missed' and 'Skipped' (legitimate) for real statistics." },
                { name: "Frequency Control", desc: "Set habits for specific days (e.g., Mon, Wed, Fri) or daily." },
                { name: "Quantifiable Goals", desc: "Track precise numbers: '2 liters of water', '10 pages read', '45 minutes workout'." },
                { name: "Streak Freeze", desc: "'Skipped' mode freezes your streak without breaking it when you're sick or on vacation." }
            ]
        },
        {
            title: "Long-Term Vision",
            description: "Because discipline without direction is useless.",
            icon: Target,
            features: [
                { name: "Macro Goals", desc: "Yearly, Quarterly and Monthly goals connected to your daily actions." },
                { name: "Life View", desc: "The 'Memento Mori' visualization: your entire life in months, from 2003 to 2088. Impactful." },
                { name: "Yearly Trends", desc: "Comparative analysis of past years. Discover which was your most productive year." },
                { name: "Category Balance", desc: "Radar chart to see if you're neglecting vital areas (Health, Work, Relationships)." }
            ]
        },
        {
            title: "Intelligence & AI",
            description: "Your second brain, powered by local AI.",
            icon: Brain,
            features: [
                { name: "AI Neural Coach", desc: "Uses Local LLM (Ollama) to analyze your data and give you customized weekly advice." },
                { name: "Mood & Energy Matrix", desc: "Track Energy and Mood on a Cartesian plane. Discover when you're at peak performance." },
                { name: "Privacy First AI", desc: "The AI runs on YOUR computer. No data is sent to external servers or cloud AI." },
                { name: "Correlations", desc: "The system learns: 'When you sleep poorly (Mood), you often skip workouts (Habit)'." }
            ]
        },
        {
            title: "Utilities Suite",
            description: "All the tools you need, in one place.",
            icon: Database,
            features: [
                { name: "Reading Tracker", desc: "Specific calendar for reading. Track pages and daily consistency." },
                { name: "Markdown Memos", desc: "Integrated text editor with Markdown support for quick notes and ideas." },
                { name: "Smart Deletion", desc: "Intelligent archiving (Soft Delete) to not lose the history of deleted habits." },
                { name: "Full Backup", desc: "Export all your data in JSON with one click. You own your information." }
            ]
        }
    ];

    return (
        <div className="min-h-screen bg-black text-white selection:bg-purple-900 selection:text-white overflow-x-hidden">

            {/* Navigation */}
            {/* Navigation */}
            <PublicHeader />

            {/* Hero Section */}
            <section className="pt-32 pb-20 px-6 relative overflow-hidden">
                <div className="container mx-auto max-w-4xl text-center">
                    <motion.div
                        initial={{ opacity: 0, scale: 0.95 }}
                        animate={{ opacity: 1, scale: 1 }}
                        transition={{ duration: 0.5 }}
                        className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-purple-500/10 border border-purple-500/20 text-xs font-medium text-purple-300 mb-6"
                    >
                        <Zap size={12} />
                        <span>Full Feature List</span>
                    </motion.div>

                    <motion.h1
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        className="text-5xl md:text-7xl font-bold tracking-tight mb-8"
                    >
                        More Than Just <br />
                        <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
                            Checkboxes.
                        </span>
                    </motion.h1>

                    <motion.p
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ delay: 0.1 }}
                        className="text-lg md:text-xl text-zinc-400 max-w-2xl mx-auto leading-relaxed"
                    >
                        A true operating system for life. Every module is designed to work in synergy with the others.
                    </motion.p>
                </div>
            </section>

            {/* Features Grid */}
            <section className="py-12 px-6">
                <div className="container mx-auto max-w-6xl space-y-24">

                    {featureSections.map((section, idx) => (
                        <div key={idx} className="relative">
                            {/* Section Header */}
                            <div className="flex flex-col md:flex-row items-start md:items-end gap-4 mb-12 pb-6 border-b border-white/10">
                                <div>
                                    <div className="flex items-center gap-3 mb-2">
                                        <section.icon className="text-purple-500" size={28} />
                                        <h2 className="text-3xl font-bold">{section.title}</h2>
                                    </div>
                                    <p className="text-zinc-400 text-lg">{section.description}</p>
                                </div>
                            </div>

                            {/* Cards Grid */}
                            <motion.div
                                variants={container}
                                initial="initial"
                                whileInView="animate"
                                viewport={{ once: true, margin: "-100px" }}
                                className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6"
                            >
                                {section.features.map((feature, fIdx) => (
                                    <motion.div
                                        key={fIdx}
                                        variants={fadeInUp}
                                        className="p-6 rounded-2xl bg-zinc-900/30 border border-white/5 hover:bg-zinc-800/50 hover:border-purple-500/20 transition-all duration-300 group"
                                    >
                                        <h3 className="font-bold text-lg mb-3 group-hover:text-purple-300 transition-colors">
                                            {feature.name}
                                        </h3>
                                        <p className="text-sm text-zinc-500 leading-relaxed">
                                            {feature.desc}
                                        </p>
                                    </motion.div>
                                ))}
                            </motion.div>
                        </div>
                    ))}

                </div>
            </section>

            {/* Technical Note */}
            <section className="py-20 px-6 bg-zinc-900/20 mt-20 border-y border-white/5">
                <div className="container mx-auto max-w-4xl text-center">
                    <Smartphone className="w-12 h-12 text-zinc-500 mx-auto mb-6" />
                    <h2 className="text-2xl font-bold mb-4">Mobile & Desktop Native</h2>
                    <p className="text-zinc-400 mb-8 max-w-2xl mx-auto">
                        All these features are 100% accessible from any device.
                        The interface adapts fluidly from your desktop's 4K monitor to your smartphone screen.
                    </p>
                    <div className="flex justify-center gap-4 text-sm text-zinc-500">
                        <span className="flex items-center gap-2"><CheckCircle2 size={16} /> iOS Ready</span>
                        <span className="flex items-center gap-2"><CheckCircle2 size={16} /> Android Ready</span>
                        <span className="flex items-center gap-2"><CheckCircle2 size={16} /> MacOS/Windows</span>
                    </div>
                </div>
            </section>


            {/* Footer */}
            <PublicFooter />
        </div>
    );
};

export default FeaturesPage;
