
import { useState } from "react";
import { motion } from "framer-motion";
import {
    Terminal, Database, Play, Download, Copy, Check,
    ArrowRight, ArrowLeft, ChevronRight, AlertTriangle,
    Lock as LockIcon, Globe, Cloud, Github
} from "lucide-react";
import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { useToast } from "@/components/ui/use-toast";
import PublicHeader from "@/components/PublicHeader";

const GetStartedPage = () => {
    const [copiedStep, setCopiedStep] = useState<string | null>(null);
    const { toast } = useToast();

    const handleCopy = (text: string, stepId: string) => {
        navigator.clipboard.writeText(text);
        setCopiedStep(stepId);
        toast({
            title: "Copied to clipboard!",
            duration: 2000,
        });
        setTimeout(() => setCopiedStep(null), 2000);
    };

    const fadeInUp = {
        initial: { opacity: 0, y: 20 },
        animate: { opacity: 1, y: 0 },
        transition: { duration: 0.5 }
    };

    // Simplified Schema for display - ideally this links to the file or downloads it
    const schemaUrl = "https://raw.githubusercontent.com/simo-hue/mattioli.OS/main/schema.sql";

    return (
        <div className="min-h-screen bg-black text-white selection:bg-green-900 selection:text-white overflow-x-hidden">
            {/* Navigation */}
            {/* Navigation */}
            <PublicHeader />

            {/* Hero Section */}
            <section className="pt-32 pb-12 px-6">
                <div className="container mx-auto max-w-4xl text-center">
                    <motion.h1
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}

                        className="text-4xl md:text-6xl font-bold tracking-tight mb-6"
                    >
                        Your OS in 10 minutes.
                    </motion.h1>
                    <motion.p
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ delay: 0.1 }}
                        className="text-lg text-zinc-400 max-w-2xl mx-auto"
                    >
                        You don't need to be an expert programmer. Follow this step-by-step guide to install EVOLVE on your computer and become operational today.
                    </motion.p>
                </div>
            </section>

            {/* Steps */}
            <section className="py-12 px-6">
                <div className="container mx-auto max-w-3xl space-y-12">

                    {/* Step 1: Prerequisites */}
                    <div className="relative pl-8 border-l border-white/10 pb-12">
                        <span className="absolute -left-4 top-0 flex h-8 w-8 items-center justify-center rounded-full bg-zinc-900 ring-2 ring-white/10">1</span>
                        <div className="mb-4">
                            <h2 className="text-2xl font-bold mb-2 flex items-center gap-2">
                                <Download className="text-blue-400" /> Prerequisites
                            </h2>
                            <p className="text-zinc-400">Before you start, make sure you have this software installed.</p>
                        </div>
                        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                            <a href="https://code.visualstudio.com/" target="_blank" rel="noopener noreferrer" className="p-4 rounded-xl bg-zinc-900/50 border border-white/5 hover:bg-zinc-800 transition-colors group">
                                <div className="font-bold mb-1 group-hover:text-blue-400 transition-colors">VS Code</div>
                                <div className="text-xs text-zinc-500">Code Editor</div>
                            </a>
                            <a href="https://nodejs.org/" target="_blank" rel="noopener noreferrer" className="p-4 rounded-xl bg-zinc-900/50 border border-white/5 hover:bg-zinc-800 transition-colors group">
                                <div className="font-bold mb-1 group-hover:text-green-400 transition-colors">Node.js (LTS)</div>
                                <div className="text-xs text-zinc-500">JavaScript Engine</div>
                            </a>
                            <a href="https://git-scm.com/downloads" target="_blank" rel="noopener noreferrer" className="p-4 rounded-xl bg-zinc-900/50 border border-white/5 hover:bg-zinc-800 transition-colors group">
                                <div className="font-bold mb-1 group-hover:text-amber-400 transition-colors">Git</div>
                                <div className="text-xs text-zinc-500">Version Control</div>
                            </a>
                        </div>
                    </div>

                    {/* Step 2: Database Setup */}
                    <div className="relative pl-8 border-l border-white/10 pb-12">
                        <span className="absolute -left-4 top-0 flex h-8 w-8 items-center justify-center rounded-full bg-zinc-900 ring-2 ring-white/10">2</span>
                        <div className="mb-6">
                            <h2 className="text-2xl font-bold mb-2 flex items-center gap-2">
                                <Database className="text-green-400" /> Database Setup
                            </h2>
                            <p className="text-zinc-400 mb-4">EVOLVE uses Supabase (free). Let's create your backend.</p>
                            <ol className="list-decimal list-inside space-y-2 text-zinc-300 ml-2 marker:text-zinc-500">
                                <li>Go to <a href="https://supabase.com" target="_blank" className="text-green-400 hover:underline">supabase.com</a> and create an account.</li>
                                <li>Click on <strong>"New Project"</strong> and give it a name (e.g., "My Life OS").</li>
                                <li>Once the project is ready, go to the <strong>SQL Editor</strong> section (terminal icon on the left).</li>
                                <li>Copy the code below and paste it in the editor, then click <strong>Run</strong>.</li>
                            </ol>
                        </div>

                        <div className="bg-black/50 rounded-xl border border-white/10 overflow-hidden">
                            <div className="flex items-center justify-between px-4 py-2 bg-white/5 border-b border-white/5">
                                <span className="text-xs font-mono text-zinc-400">schema.sql</span>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className="h-8 gap-2 text-xs"
                                    onClick={() => window.open(schemaUrl, "_blank")}
                                >
                                    <Download size={14} /> Download full SQL
                                </Button>
                            </div>
                            <div className="p-4 overflow-x-auto text-xs font-mono text-zinc-400 bg-black/80 h-32 relative">
                                <div className="absolute inset-0 flex items-center justify-center bg-black/60 backdrop-blur-sm z-10 text-center p-4">
                                    <p>The file is too long to display here.<br />Download it by clicking the button above.</p>
                                </div>
                            </div>
                        </div>
                        <div className="mt-4 p-4 rounded-xl bg-amber-500/10 border border-amber-500/20 flex gap-3 text-amber-200/80 text-sm">
                            <AlertTriangle className="shrink-0" size={18} />
                            <p>After running the SQL, go to <strong>Project Settings &gt; API</strong>. You'll need the <strong>Project URL</strong> and <strong>anon public key</strong> for later.</p>
                        </div>
                    </div>

                    {/* Step 3: Installation */}
                    <div className="relative pl-8 border-l border-white/10 pb-12">
                        <span className="absolute -left-4 top-0 flex h-8 w-8 items-center justify-center rounded-full bg-zinc-900 ring-2 ring-white/10">3</span>
                        <div className="mb-6">
                            <h2 className="text-2xl font-bold mb-2 flex items-center gap-2">
                                <Terminal className="text-purple-400" /> Code Installation
                            </h2>
                            <p className="text-zinc-400">Let's download the "engine" to your computer.</p>
                        </div>

                        <div className="space-y-4">
                            <p className="text-sm text-zinc-300">Open the terminal (or CMD) and paste these commands one at a time:</p>

                            <div className="group relative rounded-xl bg-zinc-900 border border-white/10 p-4">
                                <code className="block mb-2 text-sm text-purple-400 font-mono"># 1. Clone the repository</code>
                                <code className="font-mono text-sm text-zinc-300">git clone https://github.com/simo-hue/mattioli.OS.git</code>
                                <Button
                                    size="icon"
                                    variant="ghost"
                                    className="absolute right-2 top-2 opacity-0 group-hover:opacity-100 transition-opacity"
                                    onClick={() => handleCopy("git clone https://github.com/simo-hue/mattioli.OS.git", "step3-1")}
                                >
                                    {copiedStep === "step3-1" ? <Check size={16} className="text-green-500" /> : <Copy size={16} />}
                                </Button>
                            </div>

                            <div className="group relative rounded-xl bg-zinc-900 border border-white/10 p-4">
                                <code className="block mb-2 text-sm text-purple-400 font-mono"># 2. Enter the folder</code>
                                <code className="font-mono text-sm text-zinc-300">cd mattioli.OS</code>
                            </div>

                            <div className="group relative rounded-xl bg-zinc-900 border border-white/10 p-4">
                                <code className="block mb-2 text-sm text-purple-400 font-mono"># 3. Install dependencies</code>
                                <code className="font-mono text-sm text-zinc-300">npm install</code>
                                <Button
                                    size="icon"
                                    variant="ghost"
                                    className="absolute right-2 top-2 opacity-0 group-hover:opacity-100 transition-opacity"
                                    onClick={() => handleCopy("npm install", "step3-3")}
                                >
                                    {copiedStep === "step3-3" ? <Check size={16} className="text-green-500" /> : <Copy size={16} />}
                                </Button>
                            </div>
                        </div>
                    </div>

                    {/* Step 4: Environment Variables */}
                    <div className="relative pl-8 border-l border-white/10 pb-12">
                        <span className="absolute -left-4 top-0 flex h-8 w-8 items-center justify-center rounded-full bg-zinc-900 ring-2 ring-white/10">4</span>
                        <div className="mb-6">
                            <h2 className="text-2xl font-bold mb-2 flex items-center gap-2">
                                <LockIcon className="text-red-400" /> Secret Configuration
                            </h2>
                            <p className="text-zinc-400">Let's connect the code to your database.</p>
                        </div>
                        <ol className="list-decimal list-inside space-y-3 text-zinc-300 ml-2">
                            <li>Open the <code className="bg-white/10 px-1 py-0.5 rounded text-xs">mattioli.OS</code> folder with <strong>VS Code</strong>.</li>
                            <li>Find the file called <code className="bg-white/10 px-1 py-0.5 rounded text-xs">.env.example</code> (it might be hidden, use cmd+shift+. on mac).</li>
                            <li>Rename it to <code className="bg-white/10 px-1 py-0.5 rounded text-xs">.env</code>.</li>
                            <li>Open the file and paste the keys you got from Supabase in step 2.</li>
                        </ol>
                        <div className="mt-4 p-4 rounded-xl bg-zinc-900 border border-white/10 font-mono text-sm overflow-x-auto">
                            <div className="text-zinc-500"># .env file content</div>
                            <div className="text-zinc-300">VITE_SUPABASE_URL=https://your-project.supabase.co</div>
                            <div className="text-zinc-300">VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6Ikp...</div>
                        </div>
                    </div>


                    {/* Step 5: Launch */}
                    <div className="relative pl-8">
                        <span className="absolute -left-4 top-0 flex h-8 w-8 items-center justify-center rounded-full bg-green-500 ring-4 ring-black">
                            <Play size={14} className="text-black fill-current ml-0.5" />
                        </span>
                        <div className="mb-6">
                            <h2 className="text-2xl font-bold mb-2 flex items-center gap-2">
                                <span className="text-green-500">Launch!</span>
                            </h2>
                            <p className="text-zinc-400">It's the moment of truth.</p>
                        </div>

                        <div className="group relative rounded-xl bg-zinc-900 border border-green-500/30 p-4 mb-4">
                            <code className="font-mono text-sm text-green-400">npm run dev</code>
                            <Button
                                size="icon"
                                variant="ghost"
                                className="absolute right-2 top-2 opacity-0 group-hover:opacity-100 transition-opacity"
                                onClick={() => handleCopy("npm run dev", "step5")}
                            >
                                {copiedStep === "step5" ? <Check size={16} className="text-green-500" /> : <Copy size={16} />}
                            </Button>
                        </div>

                        <p className="text-zinc-400">
                            Now open your browser and go to <a href="http://localhost:8080" className="text-white hover:underline font-mono">http://localhost:8080</a> (or the indicated port).
                            <br />Welcome to EVOLVE.
                        </p>
                    </div>

                </div>
            </section>

            {/* Extra: Deployment */}
            <section className="py-12 px-6 border-t border-white/10 bg-zinc-900/10">
                <div className="container mx-auto max-w-3xl">
                    <div className="mb-8">
                        <div className="flex items-center gap-3 mb-2">
                            <span className="flex h-8 w-8 items-center justify-center rounded-full bg-blue-500/10 text-blue-400 font-bold text-sm ring-1 ring-blue-500/20">Extra</span>
                            <h2 className="text-2xl font-bold flex items-center gap-2">
                                <Globe className="text-blue-400" /> Publish Online
                            </h2>
                        </div>
                        <p className="text-zinc-400">Want to use EVOLVE from your phone or share it? Here's how to put it online for free.</p>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        {/* Option 1: Vercel */}
                        <div className="p-6 rounded-2xl bg-zinc-900 border border-white/10 hover:border-white/20 transition-colors">
                            <h3 className="text-xl font-bold mb-4 flex items-center gap-2">
                                <div className="p-1.5 rounded bg-white text-black"><svg width="14" height="14" viewBox="0 0 76 65" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M37.5274 0L75.0548 65H0L37.5274 0Z" fill="currentColor" /></svg></div>
                                Vercel (Recommended)
                            </h3>
                            <ul className="space-y-3 text-sm text-zinc-400 mb-6">
                                <li className="flex gap-2"><Check size={16} className="text-green-500 shrink-0" /> Automatic configuration</li>
                                <li className="flex gap-2"><Check size={16} className="text-green-500 shrink-0" /> Automatic updates from Git</li>
                            </ul>
                            <ol className="list-decimal list-inside space-y-2 text-zinc-300 text-sm mb-6 marker:text-zinc-500">
                                <li>Upload the project to your own <strong>GitHub</strong> repository.</li>
                                <li>Go to <a href="https://vercel.com/new" target="_blank" className="text-white hover:underline">vercel.com/new</a> and import the repo.</li>
                                <li>In settings, expand <strong>Environment Variables</strong>.</li>
                                <li>Copy the variables from your <code className="text-xs bg-white/10 px-1 py-0.5 rounded">.env</code> file (URL and Key).</li>
                                <li>Click <strong>Deploy</strong>.</li>
                            </ol>
                        </div>

                        {/* Option 2: GitHub Pages */}
                        <div className="p-6 rounded-2xl bg-zinc-900 border border-white/10 hover:border-white/20 transition-colors">
                            <h3 className="text-xl font-bold mb-4 flex items-center gap-2">
                                <Github size={20} />
                                GitHub Pages
                            </h3>
                            <ul className="space-y-3 text-sm text-zinc-400 mb-6">
                                <li className="flex gap-2"><Check size={16} className="text-green-500 shrink-0" /> Completely free</li>
                                <li className="flex gap-2"><AlertTriangle size={16} className="text-amber-500 shrink-0" /> Manual path configuration</li>
                            </ul>
                            <ol className="list-decimal list-inside space-y-2 text-zinc-300 text-sm mb-6 marker:text-zinc-500">
                                <li>In the <code className="text-xs bg-white/10 px-1 py-0.5 rounded">vite.config.ts</code> file, add <code className="text-xs bg-white/10 px-1 py-0.5 rounded">base: '/repo-name/',</code></li>
                                <li>Run <code className="text-xs bg-white/10 px-1 py-0.5 rounded">npm run build</code> in the terminal.</li>
                                <li>Upload the <code className="text-xs bg-white/10 px-1 py-0.5 rounded">dist</code> folder to GitHub.</li>
                                <li>In the repo <strong>Settings</strong>, go to <strong>Pages</strong> and select the branch/folder.</li>
                            </ol>
                        </div>
                    </div>
                </div>
            </section>

            {/* Footer CTA */}
            <section className="py-20 text-center border-t border-white/10 bg-zinc-900/20">
                <h3 className="text-2xl font-bold mb-4">Problems during installation?</h3>
                <p className="text-zinc-400 mb-8">No problem. Check the FAQ or open an Issue.</p>
                <div className="flex justify-center gap-4">
                    <Link to="/faq">
                        <Button variant="secondary">Check the FAQ</Button>
                    </Link>
                    <a href="https://github.com/simo-hue/mattioli.OS/issues" target="_blank" rel="noopener noreferrer">
                        <Button variant="outline">Ask for Help on GitHub</Button>
                    </a>
                </div>
            </section>
        </div>
    );
};

export default GetStartedPage;
