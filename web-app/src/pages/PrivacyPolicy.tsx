import { motion } from "framer-motion";
import { Shield, Lock, EyeOff, Database, Bot, FileDown, Mail } from "lucide-react";
import PublicHeader from "@/components/PublicHeader";
import PublicFooter from "@/components/PublicFooter";
import { Button } from "@/components/ui/button";
import RouteHead from "@/components/RouteHead";

const PrivacyPolicy = () => {
    const lastUpdated = "May 18, 2026";

    const sections = [
        { id: "intro", title: "1. Introduction" },
        { id: "data-collection", title: "2. Data We Collect" },
        { id: "data-storage", title: "3. Storage & Security" },
        { id: "ai-privacy", title: "4. AI Neural Coach & LLMs" },
        { id: "third-parties", title: "5. Third-Party Services" },
        { id: "user-rights", title: "6. Your Rights & Data Portability" },
        { id: "changes", title: "7. Changes to This Policy" },
        { id: "contact", title: "8. Contact Support" },
    ];

    const containerVariants = {
        hidden: { opacity: 0 },
        visible: {
            opacity: 1,
            transition: { staggerChildren: 0.1 }
        }
    };

    const itemVariants = {
        hidden: { opacity: 0, y: 20 },
        visible: { opacity: 1, y: 0, transition: { duration: 0.4 } }
    };

    const handleScrollTo = (id: string) => {
        const element = document.getElementById(id);
        if (element) {
            element.scrollIntoView({ behavior: "smooth", block: "start" });
        }
    };

    return (
        <div className="min-h-screen bg-black text-white selection:bg-purple-900 selection:text-white font-body relative overflow-x-hidden">
            <RouteHead route="privacy" />
            {/* Header */}
            <PublicHeader />

            {/* Glowing Accent */}
            <div className="absolute top-0 right-1/4 w-[600px] h-[300px] bg-purple-950/20 rounded-full blur-[140px] -z-10" />
            <div className="absolute top-1/3 left-10 w-[400px] h-[200px] bg-blue-950/10 rounded-full blur-[120px] -z-10" />

            {/* Main Content */}
            <main className="pt-32 pb-24 px-6 max-w-6xl mx-auto">
                {/* Hero Panel */}
                <motion.div 
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.6 }}
                    className="text-center mb-16"
                >
                    <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-purple-500/10 border border-purple-500/20 text-xs font-mono text-purple-300 mb-6">
                        <Shield size={12} />
                        <span>Privacy-First Philosophy</span>
                    </div>
                    <h1 className="text-4xl md:text-6xl font-bold tracking-tight mb-4 bg-gradient-to-b from-white via-white to-zinc-500 bg-clip-text text-transparent">
                        Privacy Policy
                    </h1>
                    <p className="text-zinc-400 text-sm md:text-base max-w-2xl mx-auto">
                        Your productivity should not compromise your privacy. Below you will find detailed information about how 
                        <span className="text-white font-medium"> Mattioli.OS - Daily Habits & Goals</span> and the 
                        <span className="text-white font-medium"> Mattioli.OS</span> ecosystem secure and handle your data.
                    </p>
                    <div className="text-xs text-zinc-500 font-mono mt-4">
                        Last Updated: {lastUpdated}
                    </div>
                </motion.div>

                {/* Grid Layout */}
                <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-start">
                    
                    {/* Navigation Sidebar (Desktop only) */}
                    <aside className="hidden lg:block lg:col-span-3 sticky top-28 bg-zinc-900/20 border border-white/5 rounded-2xl p-6 backdrop-blur-md">
                        <h3 className="text-xs font-semibold text-zinc-400 uppercase tracking-widest mb-4 font-mono">
                            Sections
                        </h3>
                        <ul className="space-y-3">
                            {sections.map((section) => (
                                <li key={section.id}>
                                    <button
                                        onClick={() => handleScrollTo(section.id)}
                                        className="text-sm text-zinc-500 hover:text-white transition-colors duration-200 text-left font-mono block w-full hover:translate-x-1 transform transition-transform"
                                    >
                                        {section.title}
                                    </button>
                                </li>
                            ))}
                        </ul>
                        <div className="mt-8 pt-6 border-t border-white/5 space-y-4">
                            <h4 className="text-xs font-semibold text-zinc-400 font-mono uppercase tracking-wider">
                                Quick Actions
                            </h4>
                            <a href="mailto:support@mattioli.os" className="block">
                                <Button variant="outline" className="w-full text-xs h-9 rounded-lg border-white/10 text-zinc-300 hover:bg-white hover:text-black">
                                    <Mail size={12} className="mr-2" />
                                    Email Support
                                </Button>
                            </a>
                        </div>
                    </aside>

                    {/* Policy Content */}
                    <motion.div 
                        variants={containerVariants}
                        initial="hidden"
                        animate="visible"
                        className="lg:col-span-9 space-y-12"
                    >
                        {/* Principle Card */}
                        <motion.div 
                            variants={itemVariants} 
                            className="p-6 md:p-8 rounded-2xl bg-gradient-to-r from-purple-950/20 to-zinc-900/30 border border-purple-500/20 backdrop-blur-xl relative"
                        >
                            <div className="absolute top-4 right-4 text-purple-400/30">
                                <EyeOff size={40} />
                            </div>
                            <h2 className="text-xl md:text-2xl font-bold mb-4 font-mono tracking-tight text-purple-300">
                                Our Core Covenant: Zero Data Brokerage
                            </h2>
                            <p className="text-zinc-300 leading-relaxed text-sm md:text-base">
                                Mattioli.OS is built on the philosophy of full data ownership. We do not sell your data, we do not monetize your behavior, we do not track you across apps or websites, and we show absolute zero third-party advertising. All telemetry is localized or direct to your secure database container.
                            </p>
                        </motion.div>

                        {/* Section 1: Intro */}
                        <motion.section variants={itemVariants} id="intro" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <Shield size={18} className="text-purple-400" />
                                1. Introduction
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                Welcome to Mattioli.OS - Daily Habits & Goals, a mobile companion developed in Flutter, and its paired desktop web suite Mattioli.OS. This Privacy Policy details how we govern, protect, and encrypt user records. By using the app or the web platform, you consent to the structure of this policy. If you self-host or manage local-only databases, your data stays entirely within your personal systems.
                            </p>
                        </motion.section>

                        {/* Section 2: Data Collection */}
                        <motion.section variants={itemVariants} id="data-collection" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <Lock size={18} className="text-purple-400" />
                                2. Data We Collect
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                To render and persist your productivity cycles, we process a small set of parameters:
                            </p>
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                                <div className="p-5 rounded-xl bg-zinc-900/30 border border-white/5">
                                    <h3 className="text-sm font-semibold text-white mb-2 font-mono">Habits, Goals & Milestones</h3>
                                    <p className="text-xs text-zinc-500 leading-relaxed">
                                        Data includes custom habit titles, completion records (Done, Missed, Skipped states), numeric trackers, mood grades, yearly targets, active streaks, and Memento Mori timelines.
                                    </p>
                                </div>
                                <div className="p-5 rounded-xl bg-zinc-900/30 border border-white/5">
                                    <h3 className="text-sm font-semibold text-white mb-2 font-mono">Authentication Credentials</h3>
                                    <p className="text-xs text-zinc-500 leading-relaxed">
                                        If sync is enabled, we store identifiers via secure authentication mechanisms (Google Sign-In, Sign in with Apple, or Supabase credentials) consisting only of your email and system UID.
                                    </p>
                                </div>
                            </div>
                        </motion.section>

                        {/* Section 3: Storage & Security */}
                        <motion.section variants={itemVariants} id="data-storage" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <Database size={18} className="text-purple-400" />
                                3. Storage & Security
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                Depending on how you decide to deploy and utilize the system, data resides in different layers:
                            </p>
                            <div className="space-y-4">
                                <div className="p-5 rounded-xl bg-zinc-900/30 border border-white/5">
                                    <h3 className="text-base font-semibold text-white mb-2 font-mono">Offline-First Local Storage</h3>
                                    <p className="text-xs md:text-sm text-zinc-400 leading-relaxed">
                                        On your iOS mobile device, your data is written locally using encrypted secure storage platforms. It does not exit the device unless you explicitly configure cloud backups or synchronization.
                                    </p>
                                </div>
                                <div className="p-5 rounded-xl bg-zinc-900/30 border border-white/5">
                                    <h3 className="text-base font-semibold text-white mb-2 font-mono">Secure Database Containers</h3>
                                    <p className="text-xs md:text-sm text-zinc-400 leading-relaxed">
                                        When cloud-sync is active, your records migrate in real-time using HTTPS/SSL protocols to your private Supabase database engine. Row-Level Security (RLS) policies are active at all times, preventing any other user—including system operators—from intercepting your private datasets.
                                    </p>
                                </div>
                            </div>
                        </motion.section>

                        {/* Section 4: AI Privacy */}
                        <motion.section variants={itemVariants} id="ai-privacy" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <Bot size={18} className="text-purple-400" />
                                4. AI Neural Coach & LLMs
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                One of Mattioli.OS's premium modules is the AI Neural Coach, built specifically for data correlation analysis.
                            </p>
                            <div className="p-5 rounded-xl bg-zinc-900/30 border border-purple-500/10 hover:border-purple-500/20 transition-all duration-300">
                                <h3 className="text-base font-semibold text-purple-300 mb-2 font-mono">Local-First Neural Compute</h3>
                                <p className="text-xs md:text-sm text-zinc-400 leading-relaxed mb-3">
                                    Unlike commercial trackers, our standard AI architecture executes locally. By integrating with local frameworks such as <strong className="text-white">Ollama</strong> on your local environment, data never leaves your personal device.
                                </p>
                                <p className="text-xs md:text-sm text-zinc-400 leading-relaxed">
                                    If you choose to use commercial cloud providers (such as OpenAI API or Google Gemini) within your settings, you must manually supply your own API Keys. In that case, those prompt requests migrate only directly to your chosen endpoints and are subject to their specific security disclosures. We do not intermediate your prompts.
                                </p>
                            </div>
                        </motion.section>

                        {/* Section 5: Third-Party Services */}
                        <motion.section variants={itemVariants} id="third-parties" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <Shield size={18} className="text-purple-400" />
                                5. Third-Party Services
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                We rely only on reliable infrastructure providers to coordinate cloud sync and app storefront hosting:
                            </p>
                            <ul className="list-disc list-inside space-y-2.5 text-zinc-400 text-sm md:text-base pl-2">
                                <li><strong className="text-white">Apple Inc.</strong> — Manages App Store hosting, transaction logging, crash tracking (via Sentry SDK if opted in), and Apple Sign-In authentication details.</li>
                                <li><strong className="text-white">Supabase Inc.</strong> — Secure server-side database containers and authentication nodes using highly encrypted Postgres instances.</li>
                                <li><strong className="text-white">Sentry</strong> — Optional SDK for crash diagnostics to maintain high-quality system performance.</li>
                            </ul>
                        </motion.section>

                        {/* Section 6: User Rights */}
                        <motion.section variants={itemVariants} id="user-rights" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <FileDown size={18} className="text-purple-400" />
                                6. Your Rights & Data Portability
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base font-medium">
                                Your data, your property. You maintain total sovereign command:
                            </p>
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mt-2">
                                <div className="p-4 rounded-xl border border-white/5 bg-zinc-900/20">
                                    <h4 className="text-sm font-semibold text-white mb-1.5 font-mono">100% Export Ready</h4>
                                    <p className="text-xs text-zinc-500 leading-relaxed">
                                        Use our "Complete Backup" tool to download a full structured ZIP package containing all your habits, goals, and history in plain JSON tables.
                                    </p>
                                </div>
                                <div className="p-4 rounded-xl border border-white/5 bg-zinc-900/20">
                                    <h4 className="text-sm font-semibold text-white mb-1.5 font-mono">Right to Erasure (Purge)</h4>
                                    <p className="text-xs text-zinc-500 leading-relaxed">
                                        Trigger a complete wipe from settings to completely delete your account and clear all databases from active servers. There are no residues.
                                    </p>
                                </div>
                            </div>
                        </motion.section>

                        {/* Section 7: Changes */}
                        <motion.section variants={itemVariants} id="changes" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <Shield size={18} className="text-purple-400" />
                                7. Changes to This Policy
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                We may adjust this document as the system evolves (e.g. to reflect updates to local databases or iOS platform changes). When amendments occur, we will adjust the date in the "Last Updated" panel above and post notification widgets directly inside the app interface.
                            </p>
                        </motion.section>

                        {/* Section 8: Support */}
                        <motion.section variants={itemVariants} id="contact" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <Mail size={18} className="text-purple-400" />
                                8. Contact Support
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                For any questions regarding your data privacy, server encryption, or data export routines, please reach out directly:
                            </p>
                            <div className="p-5 rounded-xl bg-zinc-900/30 border border-white/5 max-w-md">
                                <span className="text-xs text-zinc-500 uppercase tracking-widest font-mono block mb-1">Developer Contact</span>
                                <a href="mailto:support@mattioli.os" className="text-lg font-mono text-purple-400 hover:text-purple-300 transition-colors">
                                    support@mattioli.os
                                </a>
                            </div>
                        </motion.section>
                    </motion.div>
                </div>
            </main>

            {/* Footer */}
            <PublicFooter />
        </div>
    );
};

export default PrivacyPolicy;
