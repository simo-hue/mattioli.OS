import { motion } from "framer-motion";
import { FileText, Scale, UserCheck, ShieldAlert, Cpu, HeartPulse, ShieldMinus } from "lucide-react";
import PublicHeader from "@/components/PublicHeader";
import PublicFooter from "@/components/PublicFooter";
import { Button } from "@/components/ui/button";

const TermsOfService = () => {
    const lastUpdated = "May 18, 2026";

    const sections = [
        { id: "acceptance", title: "1. Acceptance of Terms" },
        { id: "license", title: "2. License & Open Source" },
        { id: "accounts", title: "3. Account Management" },
        { id: "intellectual-prop", title: "4. Intellectual Property" },
        { id: "medical-disclaimer", title: "5. Wellness Disclaimer" },
        { id: "warranty", title: "6. Limitation of Liability" },
        { id: "termination", title: "7. Termination" },
        { id: "contact", title: "8. Legal Questions" },
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
        <div className="min-h-screen bg-black text-white selection:bg-purple-900 selection:text-white font-body relative overflow-x-hidden font-sans">
            {/* Header */}
            <PublicHeader />

            {/* Glowing Accent */}
            <div className="absolute top-0 left-1/4 w-[600px] h-[300px] bg-purple-950/20 rounded-full blur-[140px] -z-10" />
            <div className="absolute top-1/3 right-10 w-[400px] h-[200px] bg-blue-950/10 rounded-full blur-[120px] -z-10" />

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
                        <Scale size={12} />
                        <span>Sovereign License Agreement</span>
                    </div>
                    <h1 className="text-4xl md:text-6xl font-bold tracking-tight mb-4 bg-gradient-to-b from-white via-white to-zinc-500 bg-clip-text text-transparent">
                        Terms of Service
                    </h1>
                    <p className="text-zinc-400 text-sm md:text-base max-w-2xl mx-auto">
                        Clear, transparent, and fair legal terms. Learn about your rights, our open-source MIT framework, 
                        and the responsibilities governing your usage of <span className="text-white font-medium">Mattioli.OS</span>.
                    </p>
                    <div className="text-xs text-zinc-500 font-mono mt-4">
                        Last Updated: {lastUpdated}
                    </div>
                </motion.div>

                {/* Grid Layout */}
                <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-start">
                    
                    {/* Navigation Sidebar */}
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
                    </aside>

                    {/* Policy Content */}
                    <motion.div 
                        variants={containerVariants}
                        initial="hidden"
                        animate="visible"
                        className="lg:col-span-9 space-y-12"
                    >
                        {/* Summary Card */}
                        <motion.div 
                            variants={itemVariants} 
                            className="p-6 md:p-8 rounded-2xl bg-gradient-to-r from-purple-950/20 to-zinc-900/30 border border-purple-500/20 backdrop-blur-xl relative"
                        >
                            <div className="absolute top-4 right-4 text-purple-400/30">
                                <FileText size={40} />
                            </div>
                            <h2 className="text-xl md:text-2xl font-bold mb-4 font-mono tracking-tight text-purple-300">
                                Sovereign User Agreement
                            </h2>
                            <p className="text-zinc-300 leading-relaxed text-sm md:text-base mb-3">
                                You own 100% of your habits, goals, and logs. Because our ecosystem is fundamentally open-source under the MIT license, you have the right to modify, copy, and self-host the code. These terms apply specifically to the official storefront applications, online sync cloud hosting, and shared service infrastructure provided by us.
                            </p>
                        </motion.div>

                        {/* Section 1: Acceptance */}
                        <motion.section variants={itemVariants} id="acceptance" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <Scale size={18} className="text-purple-400" />
                                1. Acceptance of Terms
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                By installing <span className="text-white font-medium">Mattioli.OS - Daily Habits & Goals</span>, launching its companion dashboard, or checking the "I Accept" consent checkbox during user onboarding, you represent that you have read, understood, and agreed to adhere to these Terms of Service. If you do not accept these criteria, you may not access our secure cloud backends or host databases on our infrastructure.
                            </p>
                        </motion.section>

                        {/* Section 2: License */}
                        <motion.section variants={itemVariants} id="license" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <Cpu size={18} className="text-purple-400" />
                                2. License & Open Source Frameworks
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                We grant you a revocable, non-exclusive, non-transferable, limited license to run Mattioli.OS on your personal iOS device for your own individual, non-commercial self-tracking purposes.
                            </p>
                            <div className="p-5 rounded-xl bg-zinc-900/30 border border-white/5">
                                <h3 className="text-sm font-semibold text-white mb-2 font-mono">MIT Open Source Compatibility</h3>
                                <p className="text-xs md:text-sm text-zinc-500 leading-relaxed">
                                    The software codebases for the Mattioli.OS ecosystem and the Flutter mobile client are open-source and released under the MIT License. If you clone, build, and deploy your own copy of the repository onto your personal servers or Apple developer accounts, that build is governed directly by the MIT License text. These terms govern only your usage of the official, published app store release and official cloud synchronization backends.
                                </p>
                            </div>
                        </motion.section>

                        {/* Section 3: Accounts */}
                        <motion.section variants={itemVariants} id="accounts" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <UserCheck size={18} className="text-purple-400" />
                                3. Account Management & Security
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                To register habit data in real-time across devices, you can opt to activate a free account synced to a private PostgreSQL container via Supabase:
                            </p>
                            <ul className="list-disc list-inside space-y-2.5 text-zinc-400 text-sm md:text-base pl-2">
                                <li>You are responsible for protecting the login keys, Apple Sign-In states, or Google credentials utilized to access your data workspace.</li>
                                <li>You must alert us immediately of any unauthorized breach of your secure tokens.</li>
                                <li>We reserve the right to restrict cloud storage synchronization in events of clear system abuse (e.g., automated SQL injections, credential stuffing, or severe API flooding).</li>
                            </ul>
                        </motion.section>

                        {/* Section 4: Intellectual Property */}
                        <motion.section variants={itemVariants} id="intellectual-prop" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <FileText size={18} className="text-purple-400" />
                                4. Intellectual Property & Trademarks
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                While individual source code lines are accessible under public repositories, all stylized logos, UX designs, high-end layouts, "Mattioli.OS" App Store copy, the trademark name "Mattioli.OS", and premium concept arts are owned solely by Mattioli Simone. You may not repackage or rebrand the compiled application for commercial retail distribution under our brand name without explicit written authorization.
                            </p>
                        </motion.section>

                        {/* Section 5: Wellness Disclaimer */}
                        <motion.section variants={itemVariants} id="medical-disclaimer" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <HeartPulse size={18} className="text-purple-400" />
                                5. Wellness & Medical Disclaimer
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                Mattioli.OS includes analytics modules like the **Wellness vs Output Index**, mood logs, and the **Memento Mori Life Calendar** to help you understand personal trends.
                            </p>
                            <div className="p-5 rounded-xl bg-red-950/10 border border-red-500/10 hover:border-red-500/20 transition-all duration-300">
                                <h3 className="text-sm font-semibold text-red-400 mb-2 font-mono flex items-center gap-1.5">
                                    <ShieldAlert size={14} />
                                    Not Medical or Psychological Advice
                                </h3>
                                <p className="text-xs md:text-sm text-zinc-400 leading-relaxed">
                                    All insights, correlation graphs, and habit alerts generated by Mattioli.OS are computed by general data algorithms or local artificial intelligence (AI Coach) for self-reflection purposes only. They are not medical diagnoses, professional psychological suggestions, or therapeutic advice. If you are experiencing distress, anxiety, burnout, or health concerns, please consult a licensed medical or psychological professional immediately.
                                </p>
                            </div>
                        </motion.section>

                        {/* Section 6: Limitation of Liability */}
                        <motion.section variants={itemVariants} id="warranty" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <ShieldMinus size={18} className="text-purple-400" />
                                6. Disclaimer of Warranties & Limitation of Liability
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                THE ECOSYSTEM, MOBILE CLIENT, AND COMPANION SITES ARE PROVIDED "AS IS" AND "AS AVAILABLE," WITHOUT ANY WARRANTY OF ANY TYPE.
                            </p>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                Mattioli Simone and any affiliates shall have no responsibility or liability for any direct, indirect, random, special, consequential, or punitive damages, including without limits, loss of data, loss of routine streaks, device failure, cloud storage access interruptions, or other losses resulting from:
                            </p>
                            <ul className="list-decimal list-inside space-y-2 text-zinc-400 text-sm pl-2">
                                <li>Your access to or inability to reach the companion web app or cloud database container.</li>
                                <li>Any third-party conduct or content on the hosting platforms (e.g. Supabase, Apple App Store, Google Auth).</li>
                                <li>Errors, bugs, or omissions inside the application's localized code logic.</li>
                            </ul>
                        </motion.section>

                        {/* Section 7: Termination */}
                        <motion.section variants={itemVariants} id="termination" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <ShieldAlert size={18} className="text-purple-400" />
                                7. Termination
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                You can terminate this legal agreement at any time by simply deleting your user account in settings (which wipes all records from cloud databases) and removing Mattioli.OS from your iOS mobile device. We reserve the right to suspend or block API connections immediately if we detect malicious network intrusion attempts or code exploits.
                            </p>
                        </motion.section>

                        {/* Section 8: Legal Support */}
                        <motion.section variants={itemVariants} id="contact" className="scroll-mt-28 space-y-4">
                            <h2 className="text-2xl font-bold border-b border-white/5 pb-2 font-mono text-zinc-100 flex items-center gap-2">
                                <Scale size={18} className="text-purple-400" />
                                8. Legal Questions
                            </h2>
                            <p className="text-zinc-400 leading-relaxed text-sm md:text-base">
                                For any official questions regarding our terms, copyright clearances, licensing permissions, or technical self-hosting issues, please get in touch:
                            </p>
                            <div className="p-5 rounded-xl bg-zinc-900/30 border border-white/5 max-w-md">
                                <span className="text-xs text-zinc-500 uppercase tracking-widest font-mono block mb-1">Legal Queries</span>
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

export default TermsOfService;
