import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { toast } from 'sonner';
import { useMemo } from 'react';

export const DEFAULT_CATEGORY_LABELS: Record<string, string> = {
    red: 'Rosso',
    orange: 'Arancione',
    yellow: 'Giallo',
    blue: 'Blu',
    purple: 'Viola',
    pink: 'Rosa',
    cyan: 'Ciano',
    // green removed as per previous context, but keeping key if needed or strictly following user prefs
};

// Map legacy tailwind classes to approximate hex/hsl for fallback if needed, 
// or simpler: just assume keys if no custom color is set.
// Actually, let's export the default color values too so we can use them effectively.
export const DEFAULT_CATEGORY_COLORS: Record<string, string> = {
    red: "hsl(0 65% 55%)",       // rose-500 approx
    orange: "hsl(25 60% 45%)",    // orange-500
    yellow: "hsl(45 90% 45%)",    // amber-400
    blue: "hsl(220 70% 50%)",     // blue-600
    purple: "hsl(270 70% 50%)",   // violet-600
    pink: "hsl(330 70% 50%)",     // fuchsia-500
    cyan: "hsl(170 70% 40%)",     // cyan-500
};

export interface CategoryMapping {
    label: string;
    color: string;
    archived?: boolean;
}

export interface GoalCategorySettings {
    id: string;
    user_id: string;
    mappings: Record<string, string | CategoryMapping>;
}

export function useGoalCategories() {
    const queryClient = useQueryClient();

    const { data: settings, isLoading } = useQuery({
        queryKey: ['goalCategorySettings'],
        queryFn: async () => {
            const { data: { user } } = await supabase.auth.getUser();
            if (!user) return null;

            const { data, error } = await supabase
                .from('goal_category_settings')
                .select('*')
                .eq('user_id', user.id)
                .single();

            if (error && error.code !== 'PGRST116') {
                console.error('Error fetching category settings:', error);
            }
            return data as GoalCategorySettings | null;
        },
    });

    const updateSettingsMutation = useMutation({
        mutationFn: async (newMappings: Record<string, string | CategoryMapping>) => {
            const { data: { user } } = await supabase.auth.getUser();
            if (!user) throw new Error('Not authenticated');

            const { data: existing } = await (supabase
                .from('goal_category_settings') as any)
                .select('id')
                .eq('user_id', user.id)
                .single();

            if (existing) {
                const { error } = await (supabase
                    .from('goal_category_settings') as any)
                    .update({ mappings: newMappings })
                    .eq('id', existing.id);
                if (error) throw error;
            } else {
                const { error } = await (supabase
                    .from('goal_category_settings') as any)
                    .insert({ user_id: user.id, mappings: newMappings });
                if (error) throw error;
            }
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['longTermGoals'] });
            queryClient.invalidateQueries({ queryKey: ['goalCategorySettings'] });
            toast.success('Categorie aggiornate con successo');
        },
        onError: () => {
            toast.error('Errore durante l\'aggiornamento delle categorie');
        }
    });

    // Returns ALL labels (including archived) for historical display
    const categoryLabels = useMemo(() => {
        const mappingLabels: Record<string, string> = {};
        if (settings?.mappings) {
            Object.entries(settings.mappings).forEach(([key, val]) => {
                if (typeof val === 'string') {
                    mappingLabels[key] = val;
                } else {
                    mappingLabels[key] = val.label;
                }
            });
        }
        return { ...DEFAULT_CATEGORY_LABELS, ...mappingLabels };
    }, [settings]);

    // Returns ONLY ACTIVE labels for selection dropdowns
    const activeCategoryLabels = useMemo(() => {
        const allLabels: Record<string, string> = {};

        // First, add all default categories
        Object.entries(DEFAULT_CATEGORY_LABELS).forEach(([key, label]) => {
            allLabels[key] = label;
        });

        // Then process mappings: override defaults or add custom categories
        if (settings?.mappings) {
            Object.entries(settings.mappings).forEach(([key, val]) => {
                const isArchived = typeof val !== 'string' && val.archived;

                if (isArchived) {
                    // Remove from active labels if archived (even if it was a default)
                    delete allLabels[key];
                } else {
                    // Add or override with custom label
                    if (typeof val === 'string') {
                        allLabels[key] = val;
                    } else {
                        allLabels[key] = val.label;
                    }
                }
            });
        }

        return allLabels;
    }, [settings]);


    const getLabel = (colorKey: string | null) => {
        if (!colorKey) return 'Generale';
        const entry = settings?.mappings?.[colorKey];
        if (typeof entry === 'string') return entry;
        if (entry?.label) return entry.label;
        return DEFAULT_CATEGORY_LABELS[colorKey] || colorKey;
    };

    const getColor = (colorKey: string | null) => {
        if (!colorKey) return null;
        const entry = settings?.mappings?.[colorKey];
        if (entry && typeof entry !== 'string') {
            // Even if archived, we return the color for historical display
            if (entry.color) return entry.color;
        }
        return DEFAULT_CATEGORY_COLORS[colorKey] || null;
    };

    return {
        settings,
        isLoading,
        updateSettings: updateSettingsMutation.mutate,
        getLabel,
        getColor,
        categoryLabels,
        activeCategoryLabels
    };
}
