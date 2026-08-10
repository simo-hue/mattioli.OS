import { motion } from "framer-motion";
import { ArrowRight, CheckCircle2, Target, BarChart3, Brain, Calendar, Shield } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Link } from "react-router-dom";
import LandingMobileNav from "@/components/LandingMobileNav";
import PublicHeader from "@/components/PublicHeader";
import { LandingDemo } from "@/components/demo/LandingDemo";
import PublicFooter from "@/components/PublicFooter";
import RouteHead from "@/components/RouteHead";

const LandingPage = () => {
    const fadeInUp = {
        initial: { opacity: 0, y: 20 },
        animate: { opacity: 1, y: 0 },
        transition: { duration: 0.5 }
    };

    const stagger = {
        animate: {
            transition: {
                staggerChildren: 0.1
            }
        }
    };

    return (
        <div className="min-h-screen bg-black text-white selection:bg-purple-900 selection:text-white overflow-x-hidden">
            <RouteHead route="home" />
            {/* Navigation */}
            {/* Navigation */}
            <PublicHeader />

            {/* Hero Section */}
            <section className="relative pt-32 pb-20 md:pt-48 md:pb-32 px-6">
                <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_right,_var(--tw-gradient-stops))] from-purple-900/20 via-black to-black -z-10" />

                <div className="container mx-auto max-w-4xl text-center">
                    <div className="flex flex-wrap items-center justify-center gap-3 mb-8">
                        <motion.div
                            initial={{ opacity: 0, scale: 0.95 }}
                            animate={{ opacity: 1, scale: 1 }}
                            transition={{ duration: 0.5 }}
                            className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/5 border border-white/10 text-xs font-medium text-purple-300"
                        >
                            <span className="relative flex h-2 w-2">
                                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-purple-400 opacity-75"></span>
                                <span className="relative inline-flex rounded-full h-2 w-2 bg-purple-500"></span>
                            </span>
                            System Operational
                        </motion.div>

                        <motion.div
                            initial={{ opacity: 0, scale: 0.95 }}
                            animate={{ opacity: 1, scale: 1 }}
                            transition={{ duration: 0.5, delay: 0.1 }}
                            className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-green-500/10 border border-green-500/20 text-xs font-medium text-green-300"
                        >
                            <span className="text-[10px]">✨</span>
                            Open Source & Free Forever
                        </motion.div>
                    </div>

                    <motion.h1
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        className="text-4xl md:text-7xl font-bold tracking-tight mb-6 bg-gradient-to-b from-white via-white/90 to-white/50 bg-clip-text text-transparent"
                    >
                        The Operating System <br />
                        For Your <span className="text-white">Productivity.</span>
                    </motion.h1>

                    <motion.p
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ delay: 0.1 }}
                        className="text-lg md:text-xl text-zinc-400 mb-8 max-w-2xl mx-auto leading-relaxed"
                    >
                        A complete <span className="text-white font-medium">Open Source</span> and <span className="text-white font-medium">completely free</span> suite to track habits, define macro goals and monitor your personal growth with surgical precision.
                    </motion.p>

                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ delay: 0.2 }}
                        className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16"
                    >
                        <Link to="/get-started">
                            <Button className="h-12 px-8 rounded-full bg-white text-black hover:bg-zinc-200 text-base font-medium transition-all shadow-lg hover:shadow-white/5 flex items-center gap-2">
                                Get Started Now
                                <ArrowRight size={16} />
                            </Button>
                        </Link>
                        <Link 
                            to="/philosophy"
                            className="inline-flex items-center gap-2.5 h-12 px-6 rounded-full bg-white/5 border border-white/10 hover:border-purple-500/30 text-white hover:bg-white/10 text-base font-medium transition-all"
                        >
                            <span>Discover Our Philosophy</span>
                            <ArrowRight size={16} className="text-purple-400" />
                        </Link>
                    </motion.div>
                </div>
            </section>

            {/* Demo Section - Desktop Only */}
            <section className="hidden lg:block py-16 px-6">
                <div className="container mx-auto">
                    <div className="text-center mb-12">
                        <motion.h2
                            initial={{ opacity: 0, y: 20 }}
                            whileInView={{ opacity: 1, y: 0 }}
                            viewport={{ once: true }}
                            className="text-3xl font-bold mb-4"
                        >
                            See It In Action
                        </motion.h2>
                        <motion.p
                            initial={{ opacity: 0, y: 20 }}
                            whileInView={{ opacity: 1, y: 0 }}
                            viewport={{ once: true }}
                            transition={{ delay: 0.1 }}
                            className="text-zinc-400 max-w-2xl mx-auto"
                        >
                            A complete dashboard to track your daily habits with visual analytics and mood tracking.
                        </motion.p>
                    </div>
                    <LandingDemo />
                </div>
            </section>

            {/* Core Modules Grid */}
            <section id="features" className="py-24 px-6 border-t border-white/5">
                <div className="container mx-auto max-w-6xl">
                    <motion.div
                        variants={stagger}
                        initial="initial"
                        whileInView="animate"
                        viewport={{ once: true }}
                        className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
                    >
                        {/* Daily Habits */}
                        <motion.div variants={fadeInUp} className="group p-8 rounded-2xl bg-zinc-900/50 border border-white/5 hover:border-purple-500/30 transition-all duration-300 hover:bg-zinc-900/80">
                            <div className="h-12 w-12 rounded-lg bg-purple-500/10 flex items-center justify-center mb-6 text-purple-400 group-hover:scale-110 transition-transform">
                                <CheckCircle2 size={24} />
                            </div>
                            <h3 className="text-xl font-semibold mb-3">Daily Protocol</h3>
                            <p className="text-zinc-400 leading-relaxed">
                                Track your daily habits with a tri-state system (Done, Missed, Skipped). Visual analysis of your consistency.
                            </p>
                        </motion.div>

                        {/* Macro Goals */}
                        <motion.div variants={fadeInUp} className="group p-8 rounded-2xl bg-zinc-900/50 border border-white/5 hover:border-amber-500/30 transition-all duration-300 hover:bg-zinc-900/80">
                            <div className="h-12 w-12 rounded-lg bg-amber-500/10 flex items-center justify-center mb-6 text-amber-400 group-hover:scale-110 transition-transform">
                                <Target size={24} />
                            </div>
                            <h3 className="text-xl font-semibold mb-3">Macro Goals System</h3>
                            <p className="text-zinc-400 leading-relaxed">
                                Multi-level structured planning: Weekly, Monthly, Quarterly and Yearly. Align your long-term vision with daily action.
                            </p>
                        </motion.div>

                        {/* AI Coach */}
                        <motion.div variants={fadeInUp} className="group p-8 rounded-2xl bg-zinc-900/50 border border-white/5 hover:border-blue-500/30 transition-all duration-300 hover:bg-zinc-900/80">
                            <div className="h-12 w-12 rounded-lg bg-blue-500/10 flex items-center justify-center mb-6 text-blue-400 group-hover:scale-110 transition-transform">
                                <Brain size={24} />
                            </div>
                            <h3 className="text-xl font-semibold mb-3">AI Neural Coach</h3>
                            <p className="text-zinc-400 leading-relaxed">
                                Intelligent analysis of your progress generated by local LLMs. Weekly reports and personalized optimization suggestions.
                            </p>
                        </motion.div>

                        {/* Analytics */}
                        <motion.div variants={fadeInUp} className="group p-8 rounded-2xl bg-zinc-900/50 border border-white/5 hover:border-green-500/30 transition-all duration-300 hover:bg-zinc-900/80">
                            <div className="h-12 w-12 rounded-lg bg-green-500/10 flex items-center justify-center mb-6 text-green-400 group-hover:scale-110 transition-transform">
                                <BarChart3 size={24} />
                            </div>
                            <h3 className="text-xl font-semibold mb-3">Deep Analytics</h3>
                            <p className="text-zinc-400 leading-relaxed">
                                Visualize your data through advanced charts, heatmaps and radar charts to identify patterns and areas for improvement.
                            </p>
                        </motion.div>

                        {/* Calendar */}
                        <motion.div variants={fadeInUp} className="group p-8 rounded-2xl bg-zinc-900/50 border border-white/5 hover:border-pink-500/30 transition-all duration-300 hover:bg-zinc-900/80">
                            <div className="h-12 w-12 rounded-lg bg-pink-500/10 flex items-center justify-center mb-6 text-pink-400 group-hover:scale-110 transition-transform">
                                <Calendar size={24} />
                            </div>
                            <h3 className="text-xl font-semibold mb-3">Life Calendar</h3>
                            <p className="text-zinc-400 leading-relaxed">
                                An overview of your life in weeks. "Memento Mori" visualization to maintain high urgency and focus.
                            </p>
                        </motion.div>

                        {/* Privacy */}
                        <motion.div variants={fadeInUp} className="group p-8 rounded-2xl bg-zinc-900/50 border border-white/5 hover:border-zinc-500/30 transition-all duration-300 hover:bg-zinc-900/80">
                            <div className="h-12 w-12 rounded-lg bg-zinc-500/10 flex items-center justify-center mb-6 text-zinc-400 group-hover:scale-110 transition-transform">
                                <Shield size={24} />
                            </div>
                            <h3 className="text-xl font-semibold mb-3">Private & Secure</h3>
                            <p className="text-zinc-400 leading-relaxed">
                                Your data is yours. Privacy-first architecture with Local LLM support to keep your sensitive information safe.
                            </p>
                        </motion.div>
                    </motion.div>
                </div>
            </section>

            {/* Stats Preview Section */}
            <section className="py-24 px-6 bg-zinc-900/20 border-y border-white/5">
                <div className="container mx-auto max-w-5xl text-center">
                    <h2 className="text-3xl font-bold mb-16">Designed for Peak Performance</h2>

                    <div className="relative group">
                        <div className="absolute -inset-1 bg-gradient-to-r from-purple-600 to-blue-600 rounded-lg blur opacity-25 group-hover:opacity-50 transition duration-1000"></div>
                        <div className="relative bg-black rounded-lg border border-white/10 p-2 md:p-4 shadow-2xl">
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-left p-6">
                                <div className="space-y-2">
                                    <div className="text-sm text-zinc-500 uppercase tracking-wider">Completion Rate</div>
                                    <div className="text-4xl font-mono font-bold text-white">87%</div>
                                    <div className="text-xs text-green-400 flex items-center gap-1">↑ 12% vs last month</div>
                                </div>
                                <div className="space-y-2">
                                    <div className="text-sm text-zinc-500 uppercase tracking-wider">Active Streak</div>
                                    <div className="text-4xl font-mono font-bold text-white">42 <span className="text-lg text-zinc-600">days</span></div>
                                    <div className="text-xs text-purple-400">Personal Best</div>
                                </div>
                                <div className="space-y-2">
                                    <div className="text-sm text-zinc-500 uppercase tracking-wider">Focus Time</div>
                                    <div className="text-4xl font-mono font-bold text-white">1,240 <span className="text-lg text-zinc-600">hrs</span></div>
                                    <div className="text-xs text-zinc-500">Year to Date</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </section>

            {/* Footer */}
            <PublicFooter />
        </div>
    );
};

export default LandingPage;
