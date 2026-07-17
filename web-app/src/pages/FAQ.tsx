import { useState } from "react";
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

// FAQ Data
const faqData = [
    {
        category: "Philosophy & General",
        icon: Activity,
        questions: [
            { q: "What is Mattioli.OS?", a: "It's a complete operating system for personal growth. It's not just a habit tracker, but an integrated suite for managing daily habits, long-term goals and performance analysis." },
            { q: "Why 'OS' (Operating System)?", a: "Because it aims to replace the fragmented infrastructure we usually use (scattered notes, multiple apps, Excel sheets) with a single centralized and consistent system to manage your life." },
            { q: "Is it really free?", a: "Yes, 100%. It's an Open Source project released under the MIT license. Your data is yours, there's no premium subscription." },
            { q: "How is it different from Notion or Todoist?", a: "Mattioli.OS is 'opinionated'. Notion is flexible but requires hours for setup. Todoist is focused on lists. This system is built specifically for discipline and quantitative data analysis, ready to use." },
            { q: "What is the core philosophy?", a: "It's based on 'Atomic Habits' by James Clear: 'We don't rise to the level of our goals, we fall to the level of our systems.' The focus is on reducing friction and visualizing progress." },
            { q: "Do I need to create an account?", a: "Yes, the system uses Supabase Auth to ensure your data is secure, encrypted and accessible only to you. The account is free." },
            { q: "Who is the developer?", a: "I'm Simone Mattioli, a developer passionate about productivity and data visualization. I initially built this tool for myself." },
        ]
    },
    {
        category: "Daily Protocol",
        icon: Activity,
        questions: [
            { q: "What is the 'Daily Protocol'?", a: "It's your list of non-negotiable daily habits. The heart of the system for building consistency." },
            { q: "How does the 'Tri-State' logic work?", a: "Each habit can have 3 states: 'Done' (completed, green), 'Missed' (failed, red), 'Skipped' (legitimately skipped, gray). This offers more nuance than simple yes/no." },
            { q: "What's the difference between Missed and Skipped?", a: "'Missed' penalizes your streak and statistics (you failed). 'Skipped' is neutral (e.g., you were sick or on vacation), it doesn't break the streak but doesn't contribute to the score." },
            { q: "How do I delete a habit?", a: "If the habit has historical data, it gets 'archived' (Soft Delete) to not lose past statistics. If it has no data, it gets permanently deleted." },
            { q: "Can I customize the colors?", a: "Absolutely. Each habit can have a specific color to help you visually group them (e.g., Health = Green, Work = Blue)." },
            { q: "What is a 'Streak'?", a: "It's the number of consecutive days you've completed a habit without 'Missed'. 'Skipped' keeps the streak frozen." },
            { q: "Can I set habits for specific days only?", a: "Yes, you can define the frequency (e.g., Mon, Wed, Fri). On other days the habit won't appear in your daily list." },
            { q: "Can I track numeric values?", a: "Yes, you can enable quantitative tracking (e.g., '2 liters of water', '10 pages read') in addition to completed status." },
        ]
    },
    {
        category: "Macro Goals & Vision",
        icon: Target,
        questions: [
            { q: "What are Macro Goals?", a: "These are long-term goals structured hierarchically: Yearly, Quarterly, Monthly and Weekly." },
            { q: "How do I visualize my long-term progress?", a: "There's a dedicated dashboard ('Map') with radar charts, completion trends and category analysis to see if you're balancing your life well." },
            { q: "What is the 'Memento Mori' calendar?", a: "A visualization of your life in weeks (from presumed birth to statistical death). It serves to create urgency and give value to time." },
            { q: "Can I see the history of past years?", a: "Yes, the 'All-Time' dashboard allows you to navigate through data from all years you've used the system, with aggregated KPIs." },
            { q: "Is there a limit to the number of goals?", a: "Technically no. The system handles efficient pagination even for thousands of records, but for your sanity we recommend focusing on a few priorities." },
        ]
    },
    {
        category: "AI Coach & Privacy",
        icon: Brain,
        questions: [
            { q: "How does the AI Coach work?", a: "It analyzes your data (habits, mood, goals) and generates weekly reports with personalized advice. It works like a virtual mental coach." },
            { q: "Is my data sent to OpenAI/Google?", a: "NO. By default the system is designed to use 'Local LLM' (Ollama). Data is processed locally on your machine. Privacy first." },
            { q: "What does 'Local LLM' mean?", a: "It means the artificial intelligence model (e.g., Llama 3, Mistral) runs on your computer, not on a remote server. No data leaves your network." },
            { q: "How do I configure Ollama?", a: "You need to download Ollama from the official website, install a model (e.g., `ollama run llama3`) and make sure the server is active on port 11434." },
            { q: "Can I use the system without AI?", a: "Certainly. The AI Coach is an optional module. If you don't configure it or disable it in settings, the rest of the app works perfectly." },
            { q: "Does the AI read my personal notes?", a: "Only if you explicitly allow it to generate correlations between your mood and your performance." },
        ]
    },
    {
        category: "Tech & Data",
        icon: Database,
        questions: [
            { q: "Where is the data saved?", a: "On Supabase, an open source and secure PostgreSQL database. You are the only owner of your data through authentication." },
            { q: "Can I make a backup?", a: "Yes. There's a 'Complete Backup' function that downloads a ZIP archive containing all your data in JSON format, organized by tables." },
            { q: "Can I import/export data?", a: "Yes, the backup system supports both complete export and import, useful for migrating or securing information." },
            { q: "Is there a mobile app?", a: "Yes! Mattioli.OS is available as a native iOS app in the Apple App Store. The companion web dashboard is also fully responsive and installable as a Progressive Web App (PWA) on any mobile home screen." },
            { q: "What is the tech stack?", a: "React 18, Vite, TypeScript, Tailwind CSS, shadcn/ui, Supabase, TanStack Query, Recharts." },
            { q: "Can I self-host the database?", a: "Yes, since Supabase is open source, you can host your own Docker instance if you have the technical skills to do so." },
        ]
    },
    {
        category: "Troubleshooting & Support",
        icon: Code2,
        questions: [
            { q: "I found a bug, what do I do?", a: "Open an issue on GitHub. The project is actively maintained and community contributions are welcome." },
            { q: "Why isn't the AI responding?", a: "Verify that Ollama is running (`ollama serve`) and that the selected model is downloaded. Also check that the browser isn't blocking calls to localhost (CORS)." },
            { q: "The site seems slow with lots of data?", a: "We've implemented recursive pagination and virtual scrolling. If you notice slowdowns above 100k records, let us know." },
            { q: "How do I update to the new version?", a: "If you use the web version, simply refresh the page. If you cloned the repo, do `git pull` and `npm run build`." },
        ]
    }
];

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
