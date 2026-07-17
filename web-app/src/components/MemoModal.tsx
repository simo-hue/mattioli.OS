import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Dialog, DialogContent, DialogTrigger, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { ScrollArea } from '@/components/ui/scroll-area';
import { FileText, Eye, Edit2, X, Maximize2, Minimize2, Check, AlertCircle, Cloud, Loader2 } from 'lucide-react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { cn } from '@/lib/utils';
import { toast } from 'sonner';

export function MemoModal() {
    const [isOpen, setIsOpen] = useState(false);
    const [content, setContent] = useState('');
    const [mode, setMode] = useState<'edit' | 'preview'>('preview');
    const [isFullscreen, setIsFullscreen] = useState(false);

    const [syncStatus, setSyncStatus] = useState<'idle' | 'saving' | 'saved' | 'error'>('idle');

    // Initial load
    useEffect(() => {
        const loadMemo = async () => {
            const { data: { session } } = await supabase.auth.getSession();
            if (!session) return;

            const { data, error } = await (supabase
                .from('user_memos') as any)
                .select('content')
                .eq('user_id', session.user.id)
                .single();

            if (data) {
                setContent(data.content || '');
            } else if (!error) {
                // No row yet, default content
                setContent('# Note\n\nScrivi qui i tuoi appunti...');
            }
        };
        loadMemo();
    }, []);

    // Save with debounce
    useEffect(() => {
        setSyncStatus('idle');
        const saveTimeout = setTimeout(async () => {
            const { data: { session } } = await supabase.auth.getSession();
            if (!session) return;

            setSyncStatus('saving');
            const { error } = await (supabase
                .from('user_memos') as any)
                .upsert({
                    user_id: session.user.id,
                    content: content,
                    updated_at: new Date().toISOString()
                }, { onConflict: 'user_id' });

            if (error) {
                console.error('Error saving memo:', error);
                setSyncStatus('error');
                toast.error('Errore salvataggio nota: ' + (error.message || 'Errore sconosciuto'));
            } else {
                setSyncStatus('saved');
            }
        }, 1000); // 1s debounce

        return () => clearTimeout(saveTimeout);
    }, [content]);

    return (
        <Dialog open={isOpen} onOpenChange={setIsOpen}>
            <DialogTrigger asChild>
                <Button
                    variant="outline"
                    size="icon"
                    className="h-10 w-10 sm:h-9 sm:w-9"
                    title="Memo / Appunti"
                >
                    <FileText className="h-4 w-4" />
                </Button>
            </DialogTrigger>
            <DialogContent className={cn(
                "flex flex-col gap-0 p-0 sm:max-w-xl transition-all duration-300 [&>button:last-child]:hidden",
                isFullscreen ? "w-[95vw] h-[95vh] sm:max-w-[95vw]" : "h-[80vh]"
            )}>
                <DialogDescription className="sr-only">
                    Editor di testo in markdown per appunti temporanei e veloci.
                </DialogDescription>

                {/* Header */}
                <div className="flex items-center justify-between p-4 border-b border-border/40">
                    <div className="flex items-center gap-2">
                        <DialogTitle className="font-semibold text-lg">Memo</DialogTitle>
                        <span className="text-xs text-muted-foreground bg-muted/50 px-2 py-0.5 rounded">
                            .md support
                        </span>

                        {/* Sync Status Indicator */}
                        <div className="flex items-center gap-1.5 ml-2 text-xs transition-all duration-300">
                            {syncStatus === 'saving' && (
                                <>
                                    <Loader2 className="w-3 h-3 animate-spin text-muted-foreground" />
                                    <span className="text-muted-foreground">Salvataggio...</span>
                                </>
                            )}
                            {syncStatus === 'saved' && (
                                <>
                                    <Check className="w-3 h-3 text-green-500" />
                                    <span className="text-green-500 font-medium">Salvato</span>
                                </>
                            )}
                            {syncStatus === 'error' && (
                                <>
                                    <AlertCircle className="w-3 h-3 text-destructive" />
                                    <span className="text-destructive font-medium">Errore Sync</span>
                                </>
                            )}
                        </div>
                    </div>
                    <div className="flex items-center gap-1">
                        <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => setMode(mode === 'preview' ? 'edit' : 'preview')}
                            className="gap-2 h-8"
                            title={mode === 'preview' ? "Modifica" : "Visualizza"}
                        >
                            {mode === 'preview' ? (
                                <>
                                    <Edit2 className="w-4 h-4" />
                                    <span className="hidden sm:inline">Modifica</span>
                                </>
                            ) : (
                                <>
                                    <Eye className="w-4 h-4" />
                                    <span className="hidden sm:inline">Anteprima</span>
                                </>
                            )}
                        </Button>

                        <Button
                            variant="ghost"
                            size="icon"
                            className="h-8 w-8"
                            onClick={() => setIsFullscreen(!isFullscreen)}
                            title={isFullscreen ? "Riduci" : "Espandi"}
                        >
                            {isFullscreen ? <Minimize2 className="w-4 h-4" /> : <Maximize2 className="w-4 h-4" />}
                        </Button>

                        <Button
                            variant="ghost"
                            size="icon"
                            className="h-8 w-8"
                            onClick={() => setIsOpen(false)}
                        >
                            <X className="w-4 h-4" />
                        </Button>
                    </div>
                </div>

                {/* Content */}
                <div className="flex-1 overflow-hidden relative bg-card">
                    {mode === 'edit' ? (
                        <Textarea
                            value={content}
                            onChange={(e) => setContent(e.target.value)}
                            className="w-full h-full resize-none p-6 font-mono text-sm bg-transparent border-0 focus-visible:ring-0 leading-relaxed"
                            placeholder="# Inizia a scrivere..."
                        />
                    ) : (
                        <ScrollArea className="h-full w-full">
                            <div className="p-6 prose prose-invert prose-sm max-w-none">
                                <ReactMarkdown
                                    remarkPlugins={[remarkGfm]}
                                    components={{
                                        h1: ({ node, ...props }) => <h1 className="text-3xl font-bold mt-2 mb-6" {...props} />,
                                        h2: ({ node, ...props }) => <h2 className="text-2xl font-bold mt-6 mb-4 border-b border-border/50 pb-2" {...props} />,
                                        code: ({ node, className, children, ...props }) => {
                                            const match = /language-(\w+)/.exec(className || '')
                                            return !String(children).includes('\n') ? (
                                                <code className="bg-primary/20 text-primary rounded px-1.5 py-0.5 font-mono text-sm" {...props}>
                                                    {children}
                                                </code>
                                            ) : (
                                                <code className={className} {...props}>
                                                    {children}
                                                </code>
                                            )
                                        }
                                    }}
                                >
                                    {content}
                                </ReactMarkdown>
                            </div>
                        </ScrollArea>
                    )}
                </div>
            </DialogContent>
        </Dialog>
    );
}
