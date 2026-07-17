import { useState, useMemo, useEffect } from 'react';
import { Plus, Trash2, Settings, Pencil, X, Check, GripVertical } from 'lucide-react';
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
import { Goal } from '@/types/goals';
import { ColorPicker } from '@/components/ui/color-picker';
import { cn } from '@/lib/utils';
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

import {
    DndContext,
    closestCenter,
    KeyboardSensor,
    PointerSensor,
    TouchSensor,
    useSensor,
    useSensors,
    DragEndEvent,
} from '@dnd-kit/core';
import {
    arrayMove,
    SortableContext,
    sortableKeyboardCoordinates,
    verticalListSortingStrategy,
    useSortable,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';

interface HabitSettingsProps {
    habits: Goal[];
    onAddHabit: (goal: { title: string; color: string }) => void;
    onRemoveHabit: (id: string) => void;
    onUpdateHabit?: (data: { id: string; title: string; color: string }) => void;
    onUpdateOrder?: (reorderedGoals: { id: string; display_order: number }[]) => void;
    isDeleting?: boolean;
    isUpdating?: boolean;
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

// Sortable Habit Item Component
interface SortableHabitItemProps {
    habit: Goal;
    isEditing: boolean;
    editTitle: string;
    editColor: string;
    isPrivacyMode: boolean;
    isDeleting?: boolean;
    isUpdating?: boolean;
    onStartEdit: (habit: Goal) => void;
    onCancelEdit: () => void;
    onSaveEdit: () => void;
    onRemove: (id: string) => void;
    setEditTitle: (title: string) => void;
    setEditColor: (color: string) => void;
}

function SortableHabitItem({
    habit,
    isEditing,
    editTitle,
    editColor,
    isPrivacyMode,
    isDeleting,
    isUpdating,
    onStartEdit,
    onCancelEdit,
    onSaveEdit,
    onRemove,
    setEditTitle,
    setEditColor,
}: SortableHabitItemProps) {
    const {
        attributes,
        listeners,
        setNodeRef,
        transform,
        transition,
        isDragging,
    } = useSortable({ id: habit.id });

    const style = {
        transform: CSS.Transform.toString(transform),
        transition,
        opacity: isDragging ? 0.5 : 1,
    };

    return (
        <div ref={setNodeRef} style={style}>
            {isEditing ? (
                /* Edit Mode */
                <div className="rounded-xl p-3 bg-primary/10 border border-primary/30 space-y-3">
                    <div className="space-y-2">
                        <Label className="text-xs uppercase tracking-wider text-muted-foreground">Nome</Label>
                        <Input
                            value={editTitle}
                            onChange={(e) => setEditTitle(e.target.value)}
                            className="bg-black/30 border-white/10 h-9 rounded-lg"
                            autoFocus
                        />
                    </div>
                    <div className="space-y-2">
                        <Label className="text-xs uppercase tracking-wider text-muted-foreground">Colore</Label>
                        <ColorPicker
                            value={editColor}
                            onChange={setEditColor}
                        />
                    </div>
                    <div className="flex gap-2 pt-1">
                        <Button
                            size="sm"
                            variant="ghost"
                            onClick={onCancelEdit}
                            className="flex-1 h-8 rounded-lg"
                        >
                            <X className="h-4 w-4 mr-1" />
                            Annulla
                        </Button>
                        <Button
                            size="sm"
                            onClick={onSaveEdit}
                            disabled={!editTitle.trim() || isUpdating}
                            className="flex-1 h-8 rounded-lg"
                        >
                            <Check className="h-4 w-4 mr-1" />
                            {isUpdating ? 'Salvando...' : 'Salva'}
                        </Button>
                    </div>
                </div>
            ) : (
                /* Display Mode */
                <div className="group flex items-center gap-2 rounded-xl p-3 bg-white/5 border border-transparent hover:border-white/10 hover:bg-white/10 transition-all">
                    {/* Drag Handle */}
                    <div
                        {...attributes}
                        {...listeners}
                        className="cursor-grab active:cursor-grabbing opacity-40 group-hover:opacity-100 transition-opacity touch-none"
                    >
                        <GripVertical className="h-4 w-4 text-muted-foreground" />
                    </div>

                    {/* Habit Info */}
                    <div className="flex items-center gap-3 flex-1 min-w-0">
                        <div
                            className="h-3 w-3 rounded-full shadow-[0_0_8px_currentColor] shrink-0"
                            style={{ backgroundColor: habit.color, color: habit.color }}
                        />
                        <span className={cn("text-sm font-medium transition-all duration-300 truncate", isPrivacyMode && "blur-sm")}>
                            {habit.title}
                        </span>
                    </div>

                    {/* Action Buttons */}
                    <div className="flex items-center gap-1 shrink-0">
                        {/* Edit Button */}
                        <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => onStartEdit(habit)}
                            className="h-8 w-8 text-muted-foreground opacity-60 group-hover:opacity-100 group-hover:text-primary hover:bg-primary/10 transition-all rounded-lg"
                        >
                            <Pencil className="h-4 w-4" />
                        </Button>

                        {/* Delete Button */}
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
                                        onClick={() => onRemove(habit.id)}
                                        className="bg-destructive hover:bg-destructive/90 text-destructive-foreground"
                                        disabled={isDeleting}
                                    >
                                        {isDeleting ? 'Eliminazione...' : 'Conferma elimina'}
                                    </AlertDialogAction>
                                </AlertDialogFooter>
                            </AlertDialogContent>
                        </AlertDialog>
                    </div>
                </div>
            )}
        </div>
    );
}

export function HabitSettings({
    habits,
    onAddHabit,
    onRemoveHabit,
    onUpdateHabit,
    onUpdateOrder,
    isDeleting,
    isUpdating,
    isPrivacyMode = false
}: HabitSettingsProps) {
    const [isOpen, setIsOpen] = useState(false);

    // Memoized sorted habits to avoid re-sorting on every render
    const sortedHabits = useMemo(() => {
        return [...habits].sort((a, b) => {
            // Primary sort by display_order
            const orderA = a.display_order ?? 999999;
            const orderB = b.display_order ?? 999999;

            if (orderA !== orderB) {
                return orderA - orderB;
            }

            // Fallback to created_at if display_order is the same
            return new Date(a.created_at).getTime() - new Date(b.created_at).getTime();
        });
    }, [habits]);

    // Local state for drag & drop
    const [localHabits, setLocalHabits] = useState<Goal[]>(sortedHabits);

    useEffect(() => {
        setLocalHabits(sortedHabits);
    }, [sortedHabits]);

    const [newHabitTitle, setNewHabitTitle] = useState('');
    const [newHabitColor, setNewHabitColor] = useState('hsl(145 55% 42%)');

    // Edit mode state
    const [editingHabit, setEditingHabit] = useState<Goal | null>(null);
    const [editTitle, setEditTitle] = useState('');
    const [editColor, setEditColor] = useState('');

    // Drag & drop sensors
    const sensors = useSensors(
        useSensor(PointerSensor),
        useSensor(TouchSensor),
        useSensor(KeyboardSensor, {
            coordinateGetter: sortableKeyboardCoordinates,
        })
    );

    const handleAdd = () => {
        if (newHabitTitle.trim()) {
            onAddHabit({
                title: newHabitTitle,
                color: newHabitColor
            });
            setNewHabitTitle('');
            setNewHabitColor('hsl(145 55% 42%)');
        }
    };

    const handleStartEdit = (habit: Goal) => {
        setEditingHabit(habit);
        setEditTitle(habit.title);
        setEditColor(habit.color);
    };

    const handleCancelEdit = () => {
        setEditingHabit(null);
        setEditTitle('');
        setEditColor('');
    };

    const handleSaveEdit = () => {
        if (editingHabit && editTitle.trim() && onUpdateHabit) {
            onUpdateHabit({
                id: editingHabit.id,
                title: editTitle.trim(),
                color: editColor
            });
            handleCancelEdit();
        }
    };

    const handleDragEnd = (event: DragEndEvent) => {
        const { active, over } = event;

        if (!over || active.id === over.id) return;

        setLocalHabits((items) => {
            const oldIndex = items.findIndex((item) => item.id === active.id);
            const newIndex = items.findIndex((item) => item.id === over.id);

            const reordered = arrayMove(items, oldIndex, newIndex);

            // Persist to database
            if (onUpdateOrder) {
                const updates = reordered.map((habit, index) => ({
                    id: habit.id,
                    display_order: index + 1
                }));
                onUpdateOrder(updates);
            }

            return reordered;
        });
    };

    return (
        <Dialog open={isOpen} onOpenChange={setIsOpen}>
            <DialogTrigger asChild>
                <Button variant="outline" size="icon" className="h-10 w-10 sm:h-9 sm:w-9">
                    <Settings className="h-4 w-4" />
                </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[425px] max-h-[85vh] flex flex-col bg-[#0a0a0a]/90 backdrop-blur-2xl border-white/10 text-foreground p-0 gap-0">
                <DialogHeader className="p-6 pb-2 shrink-0">
                    <DialogTitle>Gestisci Abitudini</DialogTitle>
                    <DialogDescription>
                        Aggiungi, modifica o riordina le abitudini che vuoi tracciare. Trascina per riordinare.
                    </DialogDescription>
                </DialogHeader>

                <div className="flex-1 overflow-y-auto p-6 pt-2 space-y-8">
                    {/* Add New Habit Form */}
                    <div className="space-y-4 p-4 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-md">
                        <div className="flex items-center gap-2 mb-2">
                            <div className="h-8 w-8 rounded-full bg-primary/20 flex items-center justify-center text-primary">
                                <Plus className="h-4 w-4" />
                            </div>
                            <h4 className="text-sm font-display font-bold">Nuova Abitudine</h4>
                        </div>

                        <div className="space-y-3">
                            <div className="space-y-1.5">
                                <Label className="text-xs uppercase tracking-wider text-muted-foreground ml-1">Nome</Label>
                                <Input
                                    placeholder="Es. Bere acqua, Leggere..."
                                    value={newHabitTitle}
                                    onChange={(e) => setNewHabitTitle(e.target.value)}
                                    className="bg-black/30 border-white/10 h-10 rounded-xl"
                                />
                            </div>

                            <div className="space-y-1.5">
                                <Label className="text-xs uppercase tracking-wider text-muted-foreground ml-1">Colore</Label>
                                <ColorPicker
                                    value={newHabitColor}
                                    onChange={setNewHabitColor}
                                />
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

                    {/* List of Existing Habits with Drag & Drop */}
                    <div className="space-y-3">
                        <h4 className="text-sm font-display font-bold px-1">Le tue Abitudini</h4>
                        <DndContext
                            sensors={sensors}
                            collisionDetection={closestCenter}
                            onDragEnd={handleDragEnd}
                        >
                            <SortableContext
                                items={localHabits.map(h => h.id)}
                                strategy={verticalListSortingStrategy}
                            >
                                <div className="space-y-2">
                                    {localHabits.map((habit) => (
                                        <SortableHabitItem
                                            key={habit.id}
                                            habit={habit}
                                            isEditing={editingHabit?.id === habit.id}
                                            editTitle={editTitle}
                                            editColor={editColor}
                                            isPrivacyMode={isPrivacyMode}
                                            isDeleting={isDeleting}
                                            isUpdating={isUpdating}
                                            onStartEdit={handleStartEdit}
                                            onCancelEdit={handleCancelEdit}
                                            onSaveEdit={handleSaveEdit}
                                            onRemove={onRemoveHabit}
                                            setEditTitle={setEditTitle}
                                            setEditColor={setEditColor}
                                        />
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
                            </SortableContext>
                        </DndContext>
                    </div>
                </div>
            </DialogContent>
        </Dialog>
    );
}
