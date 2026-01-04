import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { toast } from 'sonner';
import { GoalCategorySettings } from './useGoalCategories';

export interface BackupData {
    version: number;
    timestamp: string;
    goals: any[];
    settings: GoalCategorySettings | null;
}

export interface ExportOptions {
    scope: 'all' | 'year';
    year?: number;
}

export interface ImportReport {
    totalProcessed: number;
    restored: any[]; // List of inserted goals
    updated: any[];  // List of updated goals
    unchanged: number;
    settingsUpdated: boolean;
}

export function useGoalBackup() {
    const queryClient = useQueryClient();
    const [isExporting, setIsExporting] = useState(false);
    const [isImporting, setIsImporting] = useState(false);

    const exportBackup = async (options: ExportOptions = { scope: 'all' }) => {
        setIsExporting(true);
        try {
            const { data: { user } } = await supabase.auth.getUser();
            if (!user) throw new Error('Not authenticated');

            // 1. Fetch Goals with Filters
            let query = supabase
                .from('long_term_goals')
                .select('*')
                .eq('user_id', user.id);

            if (options.scope === 'year' && options.year) {
                query = query.eq('year', options.year);
            }

            const { data: goals, error: goalsError } = await query;

            if (goalsError) throw goalsError;

            // 2. Fetch Settings
            const { data: settings, error: settingsError } = await supabase
                .from('goal_category_settings')
                .select('*')
                .eq('user_id', user.id)
                .single();

            if (settingsError && settingsError.code !== 'PGRST116') {
                throw settingsError;
            }

            // 3. Bundle Data
            const backupData: BackupData = {
                version: 1,
                timestamp: new Date().toISOString(),
                goals: goals || [],
                settings: settings || null
            };

            // 4. Download File
            const fileName = options.scope === 'all'
                ? `habit_tracker_FULL_backup_${new Date().toISOString().split('T')[0]}.json`
                : `habit_tracker_${options.year}_backup.json`;

            const blob = new Blob([JSON.stringify(backupData, null, 2)], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = fileName;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            URL.revokeObjectURL(url);

            toast.success('Backup scaricato con successo');
        } catch (error: any) {
            console.error('Export failed:', error);
            toast.error(`Errore durante l'export: ${error.message}`);
        } finally {
            setIsExporting(false);
        }
    };

    const importBackup = async (file: File): Promise<ImportReport | null> => {
        setIsImporting(true);
        return new Promise((resolve) => {
            const reader = new FileReader();

            reader.onload = async (e) => {
                try {
                    const text = e.target?.result as string;
                    if (!text) {
                        resolve(null);
                        return;
                    }

                    const backup: BackupData = JSON.parse(text);

                    // Basic Validation
                    if (!backup.version || !Array.isArray(backup.goals)) {
                        throw new Error('Formato file non valido (manca versione o goals)');
                    }

                    const { data: { user } } = await supabase.auth.getUser();
                    if (!user) throw new Error('Not authenticated');

                    // --- ANALYSIS PHASE ---
                    // Fetch existing goals with all data to compare
                    const { data: existingGoals, error: fetchError } = await (supabase
                        .from('long_term_goals') as any)
                        .select('*')
                        .eq('user_id', user.id);

                    if (fetchError) throw fetchError;

                    // Create a map for faster lookup
                    const existingGoalsMap = new Map(existingGoals?.map(g => [g.id, g]));
                    const claimedDbIds = new Set<string>(); // Track which existing goals are matched

                    const restoredGoals: any[] = [];
                    const updatedGoals: any[] = [];
                    let unchangedCount = 0;

                    const goalsToUpsert: any[] = [];

                    for (const importedGoal of backup.goals) {
                        let goalData = { ...importedGoal };

                        // Migration: Handle legacy is_completed boolean
                        if (!goalData.status && goalData.is_completed !== undefined) {
                            goalData.status = goalData.is_completed ? 'completed' : 'active';
                            delete goalData.is_completed;
                        } else if (!goalData.status) {
                            goalData.status = 'active'; // Fallback
                        }

                        let newGoal = {
                            ...goalData,
                            user_id: user.id // Force ownership
                        };

                        let existingGoal = existingGoalsMap.get(newGoal.id) as any;

                        // SMART MATCHING: If ID not found, try to find by Content (Title + Type + Year)
                        if (!existingGoal) {
                            const candidate = existingGoals?.find((g: any) =>
                                !claimedDbIds.has(g.id) &&
                                g.title === newGoal.title &&
                                g.type === newGoal.type &&
                                g.year === newGoal.year
                            );

                            if (candidate) {
                                existingGoal = candidate;
                                newGoal.id = candidate.id; // Adopt the existing ID to prevent duplicate
                            }
                        }

                        if (existingGoal) {
                            claimedDbIds.add(existingGoal.id);

                            // Compare relevant fields to check for actual changes
                            const hasChanges =
                                existingGoal.title !== newGoal.title ||
                                existingGoal.status !== newGoal.status ||
                                existingGoal.type !== newGoal.type ||
                                existingGoal.year !== newGoal.year ||
                                existingGoal.month !== newGoal.month ||
                                existingGoal.week_number !== newGoal.week_number ||
                                existingGoal.color !== newGoal.color;

                            if (hasChanges) {
                                updatedGoals.push(newGoal);
                                goalsToUpsert.push(newGoal);
                            } else {
                                unchangedCount++;
                            }
                        } else {
                            restoredGoals.push(newGoal);
                            goalsToUpsert.push(newGoal);
                        }
                    }

                    // --- ACTION PHASE ---
                    // 1. Upsert only changed or new goals
                    if (goalsToUpsert.length > 0) {
                        const { error: goalsError } = await (supabase
                            .from('long_term_goals') as any)
                            .upsert(goalsToUpsert);

                        if (goalsError) throw goalsError;
                    }

                    // 2. Restore Settings
                    let settingsUpdated = false;
                    if (backup.settings) {
                        const { data: existing } = await (supabase
                            .from('goal_category_settings') as any)
                            .select('*')
                            .eq('user_id', user.id)
                            .single();

                        const existingSettings = existing as any;

                        const settingsData = {
                            user_id: user.id,
                            mappings: backup.settings.mappings
                        };

                        // Compare settings content
                        const settingsChanged = !existingSettings || JSON.stringify(existingSettings.mappings) !== JSON.stringify(settingsData.mappings);

                        if (settingsChanged) {
                            if (existingSettings) {
                                await (supabase
                                    .from('goal_category_settings') as any)
                                    .update({ mappings: settingsData.mappings })
                                    .eq('id', existingSettings.id);
                            } else {
                                await (supabase
                                    .from('goal_category_settings') as any)
                                    .insert(settingsData);
                            }
                            settingsUpdated = true;
                        }
                    }

                    // Invalidate Queries
                    await queryClient.invalidateQueries({ queryKey: ['longTermGoals'] });
                    await queryClient.invalidateQueries({ queryKey: ['goalCategorySettings'] });

                    // Return Report
                    resolve({
                        totalProcessed: backup.goals.length,
                        restored: restoredGoals,
                        updated: updatedGoals,
                        unchanged: unchangedCount,
                        settingsUpdated
                    });

                } catch (error: any) {
                    console.error('Import failed:', error);
                    toast.error(`Errore durante l'importazione: ${error.message}`);
                    resolve(null);
                } finally {
                    setIsImporting(false);
                }
            };
            reader.readAsText(file);
        });
    };

    return {
        exportBackup,
        importBackup,
        isExporting,
        isImporting
    };
}
