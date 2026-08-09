import { motion } from "framer-motion";
import {
    Lightbulb, ArrowLeft, Target,
    Puzzle, TrendingUp, Heart
} from "lucide-react";
import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import PublicHeader from "@/components/PublicHeader";
import PublicFooter from "@/components/PublicFooter";
import RouteHead from "@/components/RouteHead";

const PhilosophyPage = () => {
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

    return (
        <div className="min-h-screen bg-black text-white selection:bg-amber-900 selection:text-white overflow-x-hidden">
            <RouteHead route="philosophy" />

            {/* Navigation */}
            {/* Navigation */}
            <PublicHeader />

            {/* Hero Section */}
            <section className="pt-32 pb-20 px-6 relative overflow-hidden">
                <div className="absolute top-0 right-1/2 translate-x-1/2 w-[800px] h-[500px] bg-amber-900/10 blur-[120px] rounded-full -z-10" />

                <div className="container mx-auto max-w-4xl text-center">
                    <motion.div
                        initial={{ opacity: 0, scale: 0.95 }}
                        animate={{ opacity: 1, scale: 1 }}
                        transition={{ duration: 0.5 }}
                        className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-amber-500/10 border border-amber-500/20 text-xs font-medium text-amber-300 mb-6"
                    >
                        <Lightbulb size={12} />
                        <span>Origin Story</span>
                    </motion.div>

                    <motion.h1
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        className="text-5xl md:text-7xl font-bold tracking-tight mb-8"
                    >
                        Built Out of <br />
                        <span className="bg-gradient-to-r from-amber-200 to-amber-500 bg-clip-text text-transparent">
                            Necessity.
                        </span>
                    </motion.h1>

                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ delay: 0.1 }}
                        className="text-lg md:text-xl text-zinc-300 max-w-3xl mx-auto leading-relaxed space-y-6 text-left"
                    >
                        <p>
                            For years I searched for software that was complete, free and capable of managing my productivity the way I wanted.
                            I started using <strong>Apple Reminders</strong>, immediate but limited.
                            Then I evolved, studying and building entire complex systems on <strong>Notion</strong>.
                        </p>
                        <p>
                            But something was always missing. No tool had that fluidity combined with the overview I was looking for.
                            Nothing that resembled this tool, which is truly one of a kind.
                        </p>
                        <p className="font-semibold text-white">
                            I couldn't find it. So I built it myself.
                        </p>
                    </motion.div>
                </div>
            </section>

            {/* Core Pillars */}
            <section className="py-20 px-6 bg-zinc-900/20 border-y border-white/5">
                <div className="container mx-auto max-w-6xl">
                    <div className="text-center mb-16">
                        <h2 className="text-3xl font-bold mb-4">The Three Pillars</h2>
                        <p className="text-zinc-400">The methodology on which Mattioli.OS is founded</p>
                    </div>

                    <motion.div
                        variants={container}
                        initial="initial"
                        whileInView="animate"
                        viewport={{ once: true }}
                        className="grid grid-cols-1 md:grid-cols-3 gap-8"
                    >
                        {/* Pillar 1 */}
                        <motion.div variants={fadeInUp} className="p-8 rounded-3xl bg-black border border-white/10 hover:border-amber-500/30 transition-colors">
                            <div className="w-12 h-12 rounded-xl bg-amber-500/10 flex items-center justify-center mb-6 text-amber-400">
                                <Puzzle size={24} />
                            </div>
                            <h3 className="text-xl font-bold mb-3">Micro & Macro Alignment</h3>
                            <p className="text-zinc-400 leading-relaxed">
                                Daily habits (Micro) make no sense without a vision (Macro).
                                The system connects every small daily action to your yearly and quarterly goals.
                            </p>
                        </motion.div>

                        {/* Pillar 2 */}
                        <motion.div variants={fadeInUp} className="p-8 rounded-3xl bg-black border border-white/10 hover:border-amber-500/30 transition-colors">
                            <div className="w-12 h-12 rounded-xl bg-amber-500/10 flex items-center justify-center mb-6 text-amber-400">
                                <TrendingUp size={24} />
                            </div>
                            <h3 className="text-xl font-bold mb-3">Data-Driven Growth</h3>
                            <p className="text-zinc-400 leading-relaxed">
                                "You can't improve what you don't measure."
                                Beyond simple "done/not done", we analyze correlations between your goals and your mood to understand what really works.
                            </p>
                        </motion.div>

                        {/* Pillar 3 */}
                        <motion.div variants={fadeInUp} className="p-8 rounded-3xl bg-black border border-white/10 hover:border-amber-500/30 transition-colors">
                            <div className="w-12 h-12 rounded-xl bg-amber-500/10 flex items-center justify-center mb-6 text-amber-400">
                                <Heart size={24} />
                            </div>
                            <h3 className="text-xl font-bold mb-3">Extreme Ownership</h3>
                            <p className="text-zinc-400 leading-relaxed">
                                No data sold. No hidden algorithms.
                                The software is open source because your productivity and sensitive data should belong only to you.
                            </p>
                        </motion.div>
                    </motion.div>
                </div>
            </section>

            {/* Quote Section */}
            <section className="py-24 px-6 relative">
                <div className="container mx-auto max-w-4xl text-center">
                    <Target className="w-16 h-16 text-amber-500/20 mx-auto mb-8" />
                    <blockquote className="text-3xl md:text-4xl font-serif italic text-zinc-300 mb-8 leading-relaxed">
                        "True freedom is not the absence of commitments, but the ability to choose your own chains. I chose discipline."
                    </blockquote>
                    <cite className="text-amber-500 not-italic font-medium">— Mattioli.OS Manifesto</cite>
                </div>
            </section>

            {/* Footer */}
            <PublicFooter />
        </div>
    );
};

export default PhilosophyPage;
