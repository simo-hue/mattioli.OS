/* eslint-disable @typescript-eslint/no-explicit-any */
import { useState, useEffect } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { toast } from "sonner";
import { Lock, Mail, Loader2, ArrowRight, ShieldCheck } from "lucide-react";

const Auth = () => {
    const [loading, setLoading] = useState(false);
    const [email, setEmail] = useState("");
    const [password, setPassword] = useState("");
    const [isSignUp, setIsSignUp] = useState(false);
    const navigate = useNavigate();

    useEffect(() => {
        // Check if user is already logged in
        supabase.auth.getSession().then(({ data: { session } }) => {
            if (session) navigate("/sw/dashboard");
        });
    }, [navigate]);

    const handleAuth = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);

        try {
            if (isSignUp) {
                toast.error("Non sei autorizzato, prova scrivi su linkedin a mattioli simone");
                return;
            } else {
                const { error } = await supabase.auth.signInWithPassword({
                    email,
                    password,
                });
                if (error) throw error;
                toast.success("Accesso effettuato");
                navigate("/sw/dashboard");
            }
        } catch (error: any) {
            toast.error(error.message);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-dvh flex items-center justify-center p-4 relative overflow-hidden bg-background">
            {/* Ambient Glow */}
            <div className="absolute inset-0 overflow-hidden pointer-events-none">
                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-primary/20 blur-[100px] rounded-full opacity-50 animate-pulse" />
                <div className="absolute top-0 right-0 w-[400px] h-[400px] bg-secondary/10 blur-[80px] rounded-full" />
            </div>

            <div className="glass-panel w-full max-w-md p-8 rounded-3xl relative z-10 border-white/10 shadow-2xl animate-scale-in">
                <div className="text-center mb-8 space-y-2">
                    <div className="inline-flex items-center justify-center w-12 h-12 rounded-xl bg-primary/10 border border-primary/20 mb-4 shadow-[0_0_15px_rgba(255,255,255,0.1)]">
                        <ShieldCheck className="w-6 h-6 text-primary" />
                    </div>
                    <h1 className="text-3xl font-display font-bold tracking-tight bg-gradient-to-br from-white to-white/60 bg-clip-text text-transparent">
                        Mattioli.OS
                    </h1>
                    <p className="text-sm text-muted-foreground font-light">
                        Sistema di tracciamento abitudini personale
                    </p>
                </div>

                <form onSubmit={handleAuth} className="space-y-4">
                    <div className="space-y-4">
                        <div className="relative group">
                            <Mail className="absolute left-3 top-3 h-5 w-5 text-muted-foreground transition-colors group-focus-within:text-primary" />
                            <Input
                                type="email"
                                placeholder="Email"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                className="pl-10 h-11 bg-black/20 border-white/10 focus:border-primary/50 focus:bg-black/40 transition-all rounded-xl"
                                required
                            />
                        </div>
                        <div className="relative group">
                            <Lock className="absolute left-3 top-3 h-5 w-5 text-muted-foreground transition-colors group-focus-within:text-primary" />
                            <Input
                                type="password"
                                placeholder="Password"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                className="pl-10 h-11 bg-black/20 border-white/10 focus:border-primary/50 focus:bg-black/40 transition-all rounded-xl"
                                required
                            />
                        </div>
                    </div>

                    <Button
                        type="submit"
                        className="w-full h-11 text-base font-medium mt-6 bg-primary hover:bg-primary/90 text-primary-foreground shadow-[0_0_20px_rgba(255,255,255,0.1)] hover:shadow-[0_0_25px_rgba(255,255,255,0.2)] transition-all duration-300"
                        disabled={loading}
                    >
                        {loading ? (
                            <Loader2 className="w-5 h-5 animate-spin" />
                        ) : (
                            <span className="flex items-center gap-2">
                                {isSignUp ? "Registrati" : "Accedi al Sistema"}
                                <ArrowRight className="w-4 h-4" />
                            </span>
                        )}
                    </Button>
                </form>

                <div className="mt-6 text-center">
                    <button
                        onClick={() => setIsSignUp(!isSignUp)}
                        className="text-xs text-muted-foreground hover:text-primary transition-colors hover:underline underline-offset-4"
                    >
                        {isSignUp
                            ? "Hai già un account? Accedi"
                            : "Prima volta? Inizializza Protocollo (Registrati)"}
                    </button>
                </div>
            </div>
        </div>
    );
};

export default Auth;
