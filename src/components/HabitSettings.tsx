import { useState } from 'react';
import { Plus, Trash2, Settings } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
    DialogDescription,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/select';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Goal } from '@/types/goals';

import { cn } from '@/lib/utils';

interface HabitSettingsProps {
    habits: Goal[];
    onAddHabit: (goal: { title: string; color: string }) => void;
    onRemoveHabit: (id: string) => void;
    isPrivacyMode?: boolean;
}

const PRESET_COLORS = [
    { name: 'Green', value: 'hsl(145 55% 42%)' },
    { name: 'Blue', value: 'hsl(220 70% 50%)' },
    { name: 'Purple', value: 'hsl(270 70% 50%)' },
    { name: 'Red', value: 'hsl(0 65% 55%)' },
    { name: 'Orange', value: 'hsl(25 60% 45%)' },
    { name: 'Pink', value: 'hsl(330 70% 50%)' },
    { name: 'Teal', value: 'hsl(170 70% 40%)' },
    { name: 'Yellow', value: 'hsl(45 90% 45%)' },
];

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
} from "@/components/ui/alert-dialog" // Manual import as not installed by shadcn yet

export function HabitSettings({ habits, onAddHabit, onRemoveHabit, isDeleting, isPrivacyMode = false }: HabitSettingsProps & { isDeleting?: boolean }) {
    const [newHabitTitle, setNewHabitTitle] = useState('');
    const [newHabitColor, setNewHabitColor] = useState(PRESET_COLORS[0].value);
    const [habitToDelete, setHabitToDelete] = useState<string | null>(null);

    const handleAdd = () => {
        if (newHabitTitle.trim()) {
            onAddHabit({ title: newHabitTitle, color: newHabitColor });
            setNewHabitTitle('');
            setNewHabitColor(PRESET_COLORS[0].value);
        }
    };

    return (
        <Dialog>
            <DialogTrigger asChild>
                <Button variant="outline" size="icon" className="h-8 w-8 sm:h-9 sm:w-9">
                    <Settings className="h-4 w-4" />
                </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[425px] bg-[#0a0a0a]/90 backdrop-blur-2xl border-white/10 text-foreground">
                <DialogHeader>
                    <DialogTitle>Gestisci Abitudini</DialogTitle>
                    <DialogDescription>
                        Aggiungi o rimuovi le abitudini che vuoi tracciare.
                    </DialogDescription>
                </DialogHeader>

                <div className="space-y-8 py-4">
                    {/* Add New Habit Form */}
                    <div className="space-y-4 p-4 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-md">
                        {/* ... form content ... */}
                        <div className="flex items-center gap-2 mb-2">
                            <div className="h-8 w-8 rounded-full bg-primary/20 flex items-center justify-center text-primary">
                                <Plus className="h-4 w-4" />
                            </div>
                            <h4 className="text-sm font-display font-bold">Nuova Abitudine</h4>
                        </div>

                        <div className="grid gap-4">
                            <div className="space-y-2">
                                <Label htmlFor="title" className="text-xs uppercase tracking-wider text-muted-foreground ml-1">Nome</Label>
                                <Input
                                    id="title"
                                    placeholder="Es. Palestra, Lettura..."
                                    value={newHabitTitle}
                                    onChange={(e) => setNewHabitTitle(e.target.value)}
                                    className="bg-black/20 border-white/10 focus:border-primary/50 text-foreground placeholder:text-muted-foreground/50 h-10 rounded-xl"
                                />
                            </div>

                            <div className="space-y-2">
                                <Label htmlFor="color" className="text-xs uppercase tracking-wider text-muted-foreground ml-1">Colore</Label>
                                <Select value={newHabitColor} onValueChange={setNewHabitColor}>
                                    <SelectTrigger className="w-full bg-black/20 border-white/10 h-10 rounded-xl">
                                        <SelectValue placeholder="Seleziona colore" />
                                    </SelectTrigger>
                                    <SelectContent className="bg-[#1a1a1a] border-white/10 backdrop-blur-xl">
                                        <div className="grid grid-cols-2 gap-1 p-1">
                                            {PRESET_COLORS.map((color) => (
                                                <SelectItem
                                                    key={color.value}
                                                    value={color.value}
                                                    className="rounded-lg hover:bg-white/10 focus:bg-white/10 cursor-pointer"
                                                >
                                                    <div className="flex items-center gap-2">
                                                        <div
                                                            className="h-3 w-3 rounded-full shadow-[0_0_8px_currentColor]"
                                                            style={{ backgroundColor: color.value, color: color.value }}
                                                        />
                                                        <span className="font-medium">{color.name}</span>
                                                    </div>
                                                </SelectItem>
                                            ))}
                                        </div>
                                    </SelectContent>
                                </Select>
                            </div>

                            <Button
                                onClick={handleAdd}
                                disabled={!newHabitTitle.trim()}
                                className="w-full rounded-xl"
                            >
                                Aggiungi al Protocollo
                            </Button>
                        </div>
                    </div>

                    {/* List of Existing Habits */}
                    <div className="space-y-4">
                        <h4 className="text-sm font-display font-bold px-1">Le tue Abitudini</h4>
                        <ScrollArea className="h-[240px] w-full rounded-2xl border border-white/5 bg-black/20 p-4">
                            <div className="space-y-2">
                                {habits.map((habit) => (
                                    <div
                                        key={habit.id}
                                        className="group flex items-center justify-between rounded-xl p-3 bg-white/5 border border-transparent hover:border-white/10 hover:bg-white/10 transition-all"
                                    >
                                        <div className="flex items-center gap-3">
                                            <div
                                                className="h-3 w-3 rounded-full shadow-[0_0_8px_currentColor]"
                                                style={{ backgroundColor: habit.color, color: habit.color }}
                                            />
                                            <span className={cn("text-sm font-medium transition-all duration-300", isPrivacyMode && "blur-sm")}>{habit.title}</span>
                                        </div>

                                        <AlertDialog>
                                            <AlertDialogTrigger asChild>
                                                <Button
                                                    variant="ghost"
                                                    size="icon"
                                                    className="h-8 w-8 text-muted-foreground opacity-60 group-hover:opacity-100 group-hover:text-destructive hover:bg-destructive/10 transition-all rounded-lg"
                                                >
                                                    <Trash2 className="h-4 w-4" />
                                                </Button>
                                            </AlertDialogTrigger>
                                            <AlertDialogContent>
                                                <AlertDialogHeader>
                                                    <AlertDialogTitle>Sei sicuro?</AlertDialogTitle>
                                                    <AlertDialogDescription>
                                                        Stai per rimuovere questa abitudine. Se ha dei dati associati, verrà archiviata per preservare lo storico. Altrimenti verrà eliminata definitivamente.
                                                    </AlertDialogDescription>
                                                </AlertDialogHeader>
                                                <AlertDialogFooter>
                                                    <AlertDialogCancel>Annulla</AlertDialogCancel>
                                                    <AlertDialogAction
                                                        onClick={() => onRemoveHabit(habit.id)}
                                                        className="bg-destructive hover:bg-destructive/90 text-destructive-foreground"
                                                        disabled={isDeleting}
                                                    >
                                                        {isDeleting ? 'Eliminazione...' : 'Conferma elimina'}
                                                    </AlertDialogAction>
                                                </AlertDialogFooter>
                                            </AlertDialogContent>
                                        </AlertDialog>
                                    </div>
                                ))}
                                {habits.length === 0 && (
                                    <div className="flex flex-col items-center justify-center py-8 text-center text-muted-foreground space-y-2">
                                        <div className="h-10 w-10 rounded-full bg-white/5 flex items-center justify-center">
                                            <Plus className="h-5 w-5 opacity-50" />
                                        </div>
                                        <p className="text-sm">Nessuna abitudine definita.</p>
                                    </div>
                                )}
                            </div>
                        </ScrollArea>
                    </div>
                </div>
            </DialogContent>
        </Dialog>
    );
}
