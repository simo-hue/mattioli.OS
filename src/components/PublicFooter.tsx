import { Link } from "react-router-dom";
import { Github, Twitter, Youtube, ArrowUpRight, ShieldCheck, FileText } from "lucide-react";

const PublicFooter = () => {
    const currentYear = new Date().getFullYear();

    const productLinks = [
        { label: "Features", path: "/features" },
        { label: "Philosophy", path: "/philosophy" },
        { label: "Tech Stack", path: "/tech" },
        { label: "Installation Guide", path: "/get-started" },
    ];

    const legalLinks = [
        { label: "Privacy Policy", path: "/privacy", icon: ShieldCheck },
        { label: "Terms of Service", path: "/terms", icon: FileText },
    ];

    const developerLinks = [
        { label: "The Founder", path: "/creator" },
        { label: "FAQ", path: "/faq" },
        { label: "GitHub Repo", path: "https://github.com/simo-hue/mattioli.OS", isExternal: true },
    ];

    return (
        <footer className="relative border-t border-white/5 bg-black text-zinc-400 py-16 px-6 overflow-hidden">
            {/* Ambient Background Glow */}
            <div className="absolute bottom-0 right-1/4 w-[500px] h-[250px] bg-purple-900/10 rounded-full blur-[120px] -z-10 pointer-events-none" />
            <div className="absolute bottom-0 left-1/4 w-[300px] h-[150px] bg-blue-900/5 rounded-full blur-[100px] -z-10 pointer-events-none" />

            <div className="container mx-auto max-w-6xl">
                <div className="grid grid-cols-1 md:grid-cols-12 gap-10 md:gap-8 pb-12 border-b border-white/5">
                    {/* Brand column */}
                    <div className="md:col-span-5 flex flex-col justify-between space-y-6">
                        <div>
                            <div className="flex items-center gap-2 mb-4">
                                <span className="text-xl font-bold tracking-widest text-white bg-gradient-to-r from-white to-zinc-400 bg-clip-text text-transparent font-mono">
                                    Mattioli.OS
                                </span>
                                <span className="px-2 py-0.5 rounded-full bg-white/5 text-[9px] font-mono border border-white/10 text-zinc-400">
                                    v4.1
                                </span>
                            </div>
                            <p className="text-sm text-zinc-500 max-w-sm leading-relaxed">
                                Master your discipline, own your data, and gamify your growth. An elegant open-source ecosystem designed for high-performance self-mastery.
                            </p>
                        </div>

                    </div>

                    {/* Links columns */}
                    <div className="md:col-span-7 grid grid-cols-2 sm:grid-cols-3 gap-8">
                        <div>
                            <h3 className="text-xs font-semibold text-white uppercase tracking-wider mb-4 font-mono">Product</h3>
                            <ul className="space-y-2.5 text-sm">
                                {productLinks.map((link) => (
                                    <li key={link.path}>
                                        <Link to={link.path} className="hover:text-white transition-colors duration-200">
                                            {link.label}
                                        </Link>
                                    </li>
                                ))}
                            </ul>
                        </div>

                        <div>
                            <h3 className="text-xs font-semibold text-white uppercase tracking-wider mb-4 font-mono">Developer</h3>
                            <ul className="space-y-2.5 text-sm">
                                {developerLinks.map((link) => (
                                    <li key={link.path}>
                                        {link.isExternal ? (
                                            <a 
                                                href={link.path} 
                                                target="_blank" 
                                                rel="noopener noreferrer" 
                                                className="hover:text-white transition-colors duration-200 inline-flex items-center gap-1"
                                            >
                                                {link.label}
                                                <ArrowUpRight size={12} className="opacity-60" />
                                            </a>
                                        ) : (
                                            <Link to={link.path} className="hover:text-white transition-colors duration-200">
                                                {link.label}
                                            </Link>
                                        )}
                                    </li>
                                ))}
                            </ul>
                        </div>

                        <div className="col-span-2 sm:col-span-1">
                            <h3 className="text-xs font-semibold text-white uppercase tracking-wider mb-4 font-mono">Legal & Privacy</h3>
                            <ul className="space-y-2.5 text-sm">
                                {legalLinks.map((link) => {
                                    const Icon = link.icon;
                                    return (
                                        <li key={link.path}>
                                            <Link to={link.path} className="hover:text-white transition-colors duration-200 inline-flex items-center gap-2">
                                                <Icon size={14} className="opacity-80" />
                                                {link.label}
                                            </Link>
                                        </li>
                                    );
                                })}
                            </ul>
                        </div>
                    </div>
                </div>

                {/* Bottom line */}
                <div className="pt-8 flex flex-col sm:flex-row justify-between items-center gap-4 text-xs text-zinc-600">
                    <div className="flex flex-wrap items-center gap-1.5 text-center sm:text-left">
                        <span>© {currentYear}</span>
                        <span className="font-semibold text-zinc-400 font-mono tracking-wider">Mattioli.OS</span>
                        <span className="h-1 w-1 rounded-full bg-zinc-800 hidden sm:inline-block" />
                        <span>Released under the MIT License.</span>
                    </div>

                    {/* Socials */}
                    <div className="flex items-center gap-4">
                        <a 
                            href="https://github.com/simo-hue" 
                            target="_blank" 
                            rel="noopener noreferrer" 
                            className="hover:text-white transition-colors duration-200"
                            aria-label="GitHub"
                        >
                            <Github size={18} />
                        </a>
                        <a 
                            href="https://x.com" 
                            target="_blank" 
                            rel="noopener noreferrer" 
                            className="hover:text-white transition-colors duration-200"
                            aria-label="X (formerly Twitter)"
                        >
                            <Twitter size={18} />
                        </a>
                        <a 
                            href="https://youtube.com" 
                            target="_blank" 
                            rel="noopener noreferrer" 
                            className="hover:text-white transition-colors duration-200"
                            aria-label="YouTube"
                        >
                            <Youtube size={18} />
                        </a>
                    </div>
                </div>
            </div>
        </footer>
    );
};

export default PublicFooter;
