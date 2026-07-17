import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from "@/components/ui/dialog";
import {
    AlertDialog,
    AlertDialogAction,
    AlertDialogCancel,
    AlertDialogContent,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogHeader,
    AlertDialogTitle,
    AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Settings2 } from "lucide-react";
import { useGoalCategories, DEFAULT_CATEGORY_LABELS, DEFAULT_CATEGORY_COLORS, CategoryMapping } from "@/hooks/useGoalCategories";
import { ColorPicker } from "@/components/ui/color-picker";
import { ScrollArea } from "@/components/ui/scroll-area"; // ScrollArea is safe here inside a fixed dialog, or verify if I should just use div overflow like before. Let's use simple div to avoid import issues or just install it. The habit settings used overflow-y-auto. I'll stick to that.

export function GoalCategorySettingsDialog() {
    const { settings, updateSettings, getColor, getLabel } = useGoalCategories();
    const [localMappings, setLocalMappings] = useState<Record<string, string | CategoryMapping>>({});
    const [open, setOpen] = useState(false);

    // Sync local state when open
    useEffect(() => {
        if (open && settings?.mappings) {
            setLocalMappings(settings.mappings);
        } else if (open) {
            setLocalMappings({});
        }
    }, [open, settings]);

    const handleSave = () => {
        updateSettings(localMappings);
        setOpen(false);
    };

    const handleLabelChange = (colorKey: string, newLabel: string) => {
        setLocalMappings(prev => {
            const current = prev[colorKey];
            const currentColor = typeof current === 'object' ? current.color : (DEFAULT_CATEGORY_COLORS[colorKey] || '');

            return {
                ...prev,
                [colorKey]: {
                    label: newLabel,
                    color: currentColor
                }
            };
        });
    };

    const handleColorChange = (colorKey: string, newColor: string) => {
        setLocalMappings(prev => {
            const current = prev[colorKey];
            const currentLabel = typeof current === 'object' ? current.label : (typeof current === 'string' ? current : (DEFAULT_CATEGORY_LABELS[colorKey] || ''));

            return {
                ...prev,
                [colorKey]: {
                    label: currentLabel,
                    color: newColor
                }
            };
        });
    };

    const getLocalValue = (key: string) => {
        const val = localMappings[key];
        if (!val) {
            // Fallback to defaults if not modified locally yet
            // Check if it exists in settings first? No, localMappings starts as settings.
            // If not in localMappings, it means it wasn't in settings either.
            // So use defaults.
            return {
                label: DEFAULT_CATEGORY_LABELS[key] || '',
                color: DEFAULT_CATEGORY_COLORS[key] || ''
            };
        }
        if (typeof val === 'string') {
            return {
                label: val,
                color: DEFAULT_CATEGORY_COLORS[key] || ''
            };
        }
        return val;
    };


    return (
        <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
                <Button variant="outline" size="icon" title="Impostazioni Categorie" className="h-10 w-10 sm:h-9 sm:w-9">
                    <Settings2 className="w-4 h-4" />
                </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[425px] flex flex-col max-h-[85vh] p-0 gap-0 bg-[#0a0a0a]/90 backdrop-blur-2xl border-white/10 text-foreground">
                <DialogHeader className="p-6 pb-2 shrink-0">
                    <DialogTitle>Personalizza Categorie</DialogTitle>
                    <DialogDescription>
                        Personalizza i colori e le etichette per i tuoi obiettivi.
                    </DialogDescription>
                </DialogHeader>

                <div className="flex-1 overflow-y-auto p-6 pt-2 space-y-4">
                    <div className="space-y-2">
                        {/* Combine default keys and local keys ensuring uniqueness */}
                        {Array.from(new Set([...Object.keys(DEFAULT_CATEGORY_LABELS), ...Object.keys(localMappings)]))
                            .filter(key => {
                                const val = localMappings[key];
                                // Hide if archived
                                if (val && typeof val !== 'string' && val.archived) return false;
                                return true;
                            })
                            .map((key) => {
                                const { label, color } = getLocalValue(key);
                                const isDefault = key in DEFAULT_CATEGORY_LABELS;

                                return (
                                    <div key={key} className="grid grid-cols-[auto_1fr_auto] items-center gap-3 p-3 rounded-lg bg-white/5 border border-white/5 group">
                                        <ColorPicker
                                            value={color || 'hsl(0 0% 50%)'}
                                            onChange={(c) => handleColorChange(key, c)}
                                            showValueLabel={false}
                                            className="w-10"
                                        />
                                        <Input
                                            id={key}
                                            value={label}
                                            placeholder={DEFAULT_CATEGORY_LABELS[key] || "Nuova Categoria"}
                                            onChange={(e) => handleLabelChange(key, e.target.value)}
                                            className="h-9 bg-black/20 border-white/10"
                                        />
                                        {!isDefault && (
                                            <AlertDialog>
                                                <AlertDialogTrigger asChild>
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        className="h-9 w-9 text-muted-foreground hover:text-destructive opacity-0 group-hover:opacity-100 transition-opacity"
                                                    >
                                                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 6h18" /><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6" /><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2" /></svg>
                                                    </Button>
                                                </AlertDialogTrigger>
                                                <AlertDialogContent>
                                                    <AlertDialogHeader>
                                                        <AlertDialogTitle>Sei sicuro?</AlertDialogTitle>
                                                        <AlertDialogDescription>
                                                            Questa azione archivierà la categoria. Verrà rimossa dalle opzioni future, ma lo storico rimarrà accessibile.
                                                        </AlertDialogDescription>
                                                    </AlertDialogHeader>
                                                    <AlertDialogFooter>
                                                        <AlertDialogCancel>Annulla</AlertDialogCancel>
                                                        <AlertDialogAction onClick={() => {
                                                            setLocalMappings(prev => {
                                                                const current = prev[key];
                                                                const currentLabel = typeof current === 'object' ? current.label : (typeof current === 'string' ? current : (DEFAULT_CATEGORY_LABELS[key] || ''));
                                                                const currentColor = typeof current === 'object' ? current.color : (DEFAULT_CATEGORY_COLORS[key] || '');

                                                                return {
                                                                    ...prev,
                                                                    [key]: {
                                                                        label: currentLabel,
                                                                        color: currentColor || 'hsl(0 0% 50%)',
                                                                        archived: true
                                                                    }
                                                                };
                                                            });
                                                        }}>
                                                            Elimina
                                                        </AlertDialogAction>
                                                    </AlertDialogFooter>
                                                </AlertDialogContent>
                                            </AlertDialog>
                                        )}
                                    </div>
                                );
                            })}
                    </div>
                    <Button
                        variant="outline"
                        className="w-full border-dashed border-white/20 hover:border-white/40 hover:bg-white/5"
                        onClick={() => {
                            const newKey = `custom_${Date.now()}`;
                            setLocalMappings(prev => ({
                                ...prev,
                                [newKey]: {
                                    label: 'Nuova Categoria',
                                    color: 'hsl(0 0% 50%)'
                                }
                            }));
                        }}
                    >
                        + Aggiungi Categoria
                    </Button>
                </div>
                <DialogFooter className="p-6 pt-2 shrink-0">
                    <Button type="submit" onClick={handleSave} className="w-full">Salva Modifiche</Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
