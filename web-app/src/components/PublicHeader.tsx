import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import LandingMobileNav from "@/components/LandingMobileNav";

const PublicHeader = () => {
    return (
        <nav className="fixed top-0 w-full z-50 border-b border-white/10 bg-black/50 backdrop-blur-md">
            <div className="container mx-auto px-6 h-16 flex items-center justify-between">
                <div className="flex items-center gap-2">
                    <Link to="/" className="flex items-center gap-2">
                        <span className="text-xl font-bold tracking-widest bg-gradient-to-r from-white to-white/60 bg-clip-text text-transparent font-mono">
                            Mattioli.OS
                        </span>
                    </Link>
                    <span className="px-2 py-0.5 rounded-full bg-white/5 text-[10px] font-medium border border-white/10 text-white/60">
                        v4.1
                    </span>
                </div>
                <div className="hidden md:flex items-center gap-8 text-sm text-zinc-400">
                    <Link to="/features" className="hover:text-white transition-colors">Features</Link>
                    <Link to="/philosophy" className="hover:text-white transition-colors">Philosophy</Link>
                    <Link to="/tech" className="hover:text-white transition-colors">Tech</Link>
                    <Link to="/creator" className="hover:text-white transition-colors">The Founder</Link>
                    <Link to="/faq" className="hover:text-white transition-colors font-medium text-purple-400">FAQ</Link>
                </div>
                <div className="hidden md:flex items-center gap-4">
                    <Link to="/get-started">
                        <Button size="sm" className="rounded-full px-4 bg-white text-black hover:bg-zinc-200 transition-colors">
                            Installation Guide
                        </Button>
                    </Link>
                </div>
                {/* Mobile Navigation Toggle */}
                <LandingMobileNav />
            </div>
        </nav>
    );
};

export default PublicHeader;
