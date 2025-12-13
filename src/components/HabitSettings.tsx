import { useState } from 'react';
import { Plus, Trash2, Settings } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
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

interface HabitSettingsProps {
    habits: Goal[];
    onAddHabit: (goal: { title: string; color: string }) => void;
    onRemoveHabit: (id: string) => void;
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

export function HabitSettings({ habits, onAddHabit, onRemoveHabit }: HabitSettingsProps) {
    const [newHabitTitle, setNewHabitTitle] = useState('');
    const [newHabitColor, setNewHabitColor] = useState(PRESET_COLORS[0].value);

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
            <DialogContent className="sm:max-w-[425px]">
                <DialogHeader>
                    <DialogTitle>Gestisci Abitudini</DialogTitle>
                    <DialogDescription>
                        Aggiungi o rimuovi le abitudini che vuoi tracciare.
                    </DialogDescription>
                </DialogHeader>

                <div className="space-y-6 py-4">
                    {/* Add New Habit Form */}
                    <div className="space-y-4 rounded-lg border p-4 bg-muted/30">
                        <h4 className="text-sm font-medium leading-none">Nuova Abitudine</h4>
                        <div className="grid gap-4">
                            <div className="grid gap-2">
                                <Label htmlFor="title">Nome</Label>
                                <Input
                                    id="title"
                                    placeholder="Es. Palestra, Lettura..."
                                    value={newHabitTitle}
                                    onChange={(e) => setNewHabitTitle(e.target.value)}
                                />
                            </div>
                            <div className="grid gap-2">
                                <Label htmlFor="color">Colore</Label>
                                <Select value={newHabitColor} onValueChange={setNewHabitColor}>
                                    <SelectTrigger className="w-full">
                                        <SelectValue placeholder="Seleziona colore" />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {PRESET_COLORS.map((color) => (
                                            <SelectItem key={color.value} value={color.value}>
                                                <div className="flex items-center gap-2">
                                                    <div
                                                        className="h-3 w-3 rounded-full"
                                                        style={{ backgroundColor: color.value }}
                                                    />
                                                    {color.name}
                                                </div>
                                            </SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </div>
                            <Button onClick={handleAdd} disabled={!newHabitTitle.trim()}>
                                <Plus className="mr-2 h-4 w-4" /> Aggiungi
                            </Button>
                        </div>
                    </div>

                    {/* List of Existing Habits */}
                    <div className="space-y-2">
                        <h4 className="text-sm font-medium leading-none mb-3">Le tue Abitudini</h4>
                        <ScrollArea className="h-[200px] w-full rounded-md border p-4">
                            <div className="space-y-3">
                                {habits.map((habit) => (
                                    <div
                                        key={habit.id}
                                        className="flex items-center justify-between rounded-md p-2 hover:bg-muted/50 transition-colors"
                                    >
                                        <div className="flex items-center gap-3">
                                            <div
                                                className="h-4 w-4 rounded-full"
                                                style={{ backgroundColor: habit.color }}
                                            />
                                            <span className="text-sm font-medium">{habit.title}</span>
                                        </div>

                                        {habits.length > 1 && (
                                            <Button
                                                variant="ghost"
                                                size="icon"
                                                className="h-8 w-8 text-destructive hover:text-destructive hover:bg-destructive/10"
                                                onClick={() => onRemoveHabit(habit.id)}
                                            >
                                                <Trash2 className="h-4 w-4" />
                                            </Button>
                                        )}
                                    </div>
                                ))}
                                {habits.length === 0 && (
                                    <p className="text-sm text-muted-foreground text-center py-4">
                                        Nessuna abitudine definita.
                                    </p>
                                )}
                            </div>
                        </ScrollArea>
                    </div>
                </div>
            </DialogContent>
        </Dialog>
    );
}
