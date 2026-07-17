import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { toast } from 'sonner';
import { createBackupZip, validateBackupData, readBackupFile } from '@/lib/backup-utils';

export interface CompleteBackupData {
    version: number;
    timestamp: string;
    metadata: {
        appVersion: string;
        exportDate: string;
        totalRecords: number;
    };
    // Database tables
    goals: any[];
    goal_logs: any[];
    long_term_goals: any[];
    goal_category_settings: any | null;
    reading_logs: any[];
    user_settings: any[];
    user_memos: any | null;
    daily_moods: any[];
    // LocalStorage
    app_settings: {
        ollama_preferred_model?: string;
        ollama_report_type?: string;
    };
    // Database Schema
    database_schema?: {
        sql: string;
        metadata: {
            supabase_version: string;
            postgrest_version: string;
            exported_at: string;
            tables_count: number;
            total_records: number;
        };
        tables_summary: {
            [tableName: string]: {
                description: string;
                key_columns: string[];
                has_rls: boolean;
                note?: string;
            };
        };
    };
}

export interface ImportDetailedReport {
    totalProcessed: number;
    byTable: {
        [tableName: string]: {
            inserted: number;
            updated: number;
            unchanged: number;
            errors: string[];
        };
    };
    settingsRestored: string[];
    timestamp: string;
}

export function useCompleteBackup() {
    const queryClient = useQueryClient();
    const [isExporting, setIsExporting] = useState(false);
    const [isImporting, setIsImporting] = useState(false);

    const exportCompleteBackup = async () => {
        setIsExporting(true);
        try {
            const { data: { user } } = await supabase.auth.getUser();
            if (!user) throw new Error('Non autenticato');

            const timestamp = new Date().toISOString();

            // Helper function for paginated fetch with progress tracking
            const fetchAllRecords = async (tableName: string, userIdFilter: boolean = true) => {
                let allRecords: any[] = [];
                let from = 0;
                const step = 1000;
                let keepFetching = true;
                let batchCount = 0;

                while (keepFetching) {
                    let query = supabase.from(tableName).select('*').range(from, from + step - 1);

                    if (userIdFilter) {
                        query = query.eq('user_id', user.id);
                    }

                    const { data, error } = await query;

                    if (error) throw error;

                    if (data && data.length > 0) {
                        batchCount++;
                        allRecords = [...allRecords, ...data];

                        // Log progress for large fetches (> 1 batch)
                        if (data.length === step) {
                            console.log(`📦 Fetching ${tableName}: batch ${batchCount} (${allRecords.length} records so far...)`);
                        }

                        if (data.length < step) {
                            keepFetching = false;
                            console.log(`✅ ${tableName}: ${allRecords.length} records fetched in ${batchCount} batch(es)`);
                        } else {
                            from += step;
                        }
                    } else {
                        keepFetching = false;
                        if (allRecords.length > 0) {
                            console.log(`✅ ${tableName}: ${allRecords.length} records fetched in ${batchCount} batch(es)`);
                        }
                    }
                }

                return allRecords;
            };

            // Fetch all database tables with pagination
            // Strategy: All tables use pagination for future-proof scalability
            // Only single-record tables (settings, memos) use direct fetch
            const [
                goals,
                goalLogs,
                longTermGoals,
                categorySettingsRes,
                readingLogs,
                userSettings,
                userMemosRes,
                dailyMoods
            ] = await Promise.all([
                // All data tables - paginated for scalability (future-proof for 10k+ records)
                fetchAllRecords('goals', true),           // Daily habits
                fetchAllRecords('goal_logs', true),       // Habit completion logs
                fetchAllRecords('long_term_goals', true), // Macro goals (~5000+)

                // Single record tables - direct fetch
                supabase.from('goal_category_settings').select('*').eq('user_id', user.id).single(),

                // All data tables - paginated for scalability
                fetchAllRecords('reading_logs', false),   // Reading logs (no user_id)
                fetchAllRecords('user_settings', false),  // User settings (no user_id)

                // Single record - direct fetch
                supabase.from('user_memos').select('*').eq('user_id', user.id).single(),

                // All data tables - paginated for scalability
                fetchAllRecords('daily_moods', true)      // Mood & Energy tracking
            ]);

            // Check for errors only on single-record queries
            if (categorySettingsRes.error && categorySettingsRes.error.code !== 'PGRST116') throw categorySettingsRes.error;
            if (userMemosRes.error && userMemosRes.error.code !== 'PGRST116') throw userMemosRes.error;

            const appSettings = {
                ollama_preferred_model: localStorage.getItem('ollama_preferred_model') || undefined,
                ollama_report_type: localStorage.getItem('ollama_report_type') || undefined,
            };

            // Fetch database schema from static file (in public/ folder)
            let schemaSQL = '';

            try {
                const schemaResponse = await fetch('/schema.sql');
                if (schemaResponse.ok) {
                    schemaSQL = await schemaResponse.text();
                } else {
                    console.warn('schema.sql not found in public folder');
                }
            } catch (error) {
                console.warn('Could not load schema.sql:', error);
            }

            // Add helpful note if schema is included
            if (schemaSQL) {
                schemaSQL = `-- HABIT TRACKER DATABASE SCHEMA
-- Exported: ${new Date().toISOString()}
-- Source: /public/schema.sql
-- 
-- This schema includes all 8 tables with RLS policies and triggers.
-- For the most up-to-date schema, export from Supabase Dashboard.
--
${schemaSQL}`;
            } else {
                schemaSQL = `-- Database Schema not available
-- 
-- To get the current database schema:
-- 1. Go to Supabase Dashboard > SQL Editor
-- 2. Copy the complete schema
-- 3. Or manually export via Supabase CLI: supabase db dump -f schema.sql
`;
            }

            // Generate database metadata
            const databaseSchema = {
                sql: schemaSQL,
                metadata: {
                    supabase_version: '2.87.1',
                    postgrest_version: '13.0.5',
                    exported_at: timestamp,
                    tables_count: 8,
                    total_records: 0 // Will be set below
                },
                tables_summary: {
                    goals: {
                        description: 'Daily habits tracking',
                        key_columns: ['id', 'user_id', 'title', 'color', 'frequency_days'],
                        has_rls: true
                    },
                    goal_logs: {
                        description: 'Habit completion logs',
                        key_columns: ['id', 'user_id', 'goal_id', 'date', 'status'],
                        has_rls: true
                    },
                    long_term_goals: {
                        description: 'Macro goals (annual, monthly, weekly, quarterly, lifetime)',
                        key_columns: ['id', 'user_id', 'title', 'type', 'year', 'month'],
                        has_rls: true
                    },
                    goal_category_settings: {
                        description: 'Category colors and labels settings',
                        key_columns: ['id', 'user_id', 'mappings'],
                        has_rls: true,
                        note: 'Single record per user'
                    },
                    reading_logs: {
                        description: 'Daily reading tracking',
                        key_columns: ['id', 'date', 'status'],
                        has_rls: true
                    },
                    user_settings: {
                        description: 'Generic user settings (key-value)',
                        key_columns: ['id', 'key', 'value'],
                        has_rls: true
                    },
                    user_memos: {
                        description: 'User personal notes in markdown',
                        key_columns: ['id', 'user_id', 'content'],
                        has_rls: true,
                        note: 'Single record per user'
                    },
                    daily_moods: {
                        description: 'Daily mood and energy tracking',
                        key_columns: ['id', 'user_id', 'date', 'mood_score', 'energy_score'],
                        has_rls: true
                    }
                }
            };

            const totalRecords =
                (goals?.length || 0) +
                (goalLogs?.length || 0) +
                (longTermGoals?.length || 0) +
                (categorySettingsRes.data ? 1 : 0) +
                (readingLogs?.length || 0) +
                (userSettings?.length || 0) +
                (userMemosRes.data ? 1 : 0) +
                (dailyMoods?.length || 0);

            // Update metadata with total records
            databaseSchema.metadata.total_records = totalRecords;

            const backupData: CompleteBackupData = {
                version: 1,
                timestamp,
                metadata: {
                    appVersion: '1.0.0',
                    exportDate: new Date().toLocaleDateString('it-IT'),
                    totalRecords
                },
                goals: goals || [],
                goal_logs: goalLogs || [],
                long_term_goals: longTermGoals || [],
                goal_category_settings: categorySettingsRes.data || null,
                reading_logs: readingLogs || [],
                user_settings: userSettings || [],
                user_memos: userMemosRes.data || null,
                daily_moods: dailyMoods || [],
                app_settings: appSettings,
                database_schema: databaseSchema
            };

            // Show progress feedback
            toast.info(`Preparazione backup: ${totalRecords} record trovati...`);

            // Create and download ZIP
            await createBackupZip(backupData, timestamp);
            toast.success(`Backup completo creato con successo! (${totalRecords} record)`);
        } catch (error: any) {
            console.error('Export failed:', error);
            toast.error(`Errore durante l'export: ${error.message}`);
        } finally {
            setIsExporting(false);
        }
    };

    const importCompleteBackup = async (file: File): Promise<ImportDetailedReport | null> => {
        setIsImporting(true);
        try {
            const backupData: CompleteBackupData = await readBackupFile(file);
            const validation = validateBackupData(backupData);
            if (!validation.valid) {
                throw new Error(`Backup non valido: ${validation.errors.join(', ')}`);
            }

            const { data: { user } } = await supabase.auth.getUser();
            if (!user) throw new Error('Non autenticato');

            const report: ImportDetailedReport = {
                totalProcessed: 0,
                byTable: {},
                settingsRestored: [],
                timestamp: new Date().toISOString()
            };

            const restoreTable = async (tableName: string, data: any[], primaryKey: string = 'id') => {
                if (!Array.isArray(data) || data.length === 0) {
                    report.byTable[tableName] = { inserted: 0, updated: 0, unchanged: 0, errors: [] };
                    return;
                }

                try {
                    const { data: existing, error: fetchError } = await supabase.from(tableName).select('*').eq('user_id', user.id);
                    if (fetchError) throw fetchError;

                    const existingMap = new Map((existing || []).map((item: any) => [item[primaryKey], item]));
                    const toUpsert: any[] = [];
                    let inserted = 0, updated = 0, unchanged = 0;

                    for (const record of data) {
                        const recordWithUser = { ...record, user_id: user.id };
                        const existingRecord = existingMap.get(record[primaryKey]);

                        if (!existingRecord) {
                            inserted++;
                            toUpsert.push(recordWithUser);
                        } else {
                            const hasChanges = JSON.stringify(existingRecord) !== JSON.stringify(recordWithUser);
                            if (hasChanges) {
                                updated++;
                                toUpsert.push(recordWithUser);
                            } else {
                                unchanged++;
                            }
                        }
                    }

                    if (toUpsert.length > 0) {
                        const { error } = await (supabase.from(tableName) as any).upsert(toUpsert);
                        if (error) throw error;
                    }

                    report.byTable[tableName] = { inserted, updated, unchanged, errors: [] };
                    report.totalProcessed += data.length;
                } catch (error: any) {
                    report.byTable[tableName] = { inserted: 0, updated: 0, unchanged: 0, errors: [error.message] };
                }
            };

            await restoreTable('goals', backupData.goals);
            await restoreTable('goal_logs', backupData.goal_logs);
            await restoreTable('long_term_goals', backupData.long_term_goals);
            await restoreTable('reading_logs', backupData.reading_logs);
            await restoreTable('user_settings', backupData.user_settings, 'key');
            await restoreTable('daily_moods', backupData.daily_moods);

            if (backupData.goal_category_settings) {
                try {
                    const { data: existing } = await supabase.from('goal_category_settings').select('*').eq('user_id', user.id).single();
                    const settingsData = { user_id: user.id, mappings: backupData.goal_category_settings.mappings };

                    if (existing) {
                        await (supabase.from('goal_category_settings') as any).update({ mappings: settingsData.mappings }).eq('id', (existing as any).id);
                        report.byTable['goal_category_settings'] = { inserted: 0, updated: 1, unchanged: 0, errors: [] };
                    } else {
                        await (supabase.from('goal_category_settings') as any).insert(settingsData);
                        report.byTable['goal_category_settings'] = { inserted: 1, updated: 0, unchanged: 0, errors: [] };
                    }
                    report.totalProcessed++;
                } catch (error: any) {
                    report.byTable['goal_category_settings'] = { inserted: 0, updated: 0, unchanged: 0, errors: [error.message] };
                }
            }

            if (backupData.user_memos) {
                try {
                    const { error } = await (supabase.from('user_memos') as any).upsert({
                        user_id: user.id,
                        content: backupData.user_memos.content || '',
                        updated_at: new Date().toISOString()
                    }, { onConflict: 'user_id' });

                    if (error) throw error;
                    report.byTable['user_memos'] = { inserted: 0, updated: 1, unchanged: 0, errors: [] };
                    report.totalProcessed++;
                } catch (error: any) {
                    report.byTable['user_memos'] = { inserted: 0, updated: 0, unchanged: 0, errors: [error.message] };
                }
            }

            if (backupData.app_settings) {
                if (backupData.app_settings.ollama_preferred_model) {
                    localStorage.setItem('ollama_preferred_model', backupData.app_settings.ollama_preferred_model);
                    report.settingsRestored.push('ollama_preferred_model');
                }
                if (backupData.app_settings.ollama_report_type) {
                    localStorage.setItem('ollama_report_type', backupData.app_settings.ollama_report_type);
                    report.settingsRestored.push('ollama_report_type');
                }
            }

            await queryClient.invalidateQueries({ queryKey: ['goals'] });
            await queryClient.invalidateQueries({ queryKey: ['goal_logs'] });
            await queryClient.invalidateQueries({ queryKey: ['longTermGoals'] });
            await queryClient.invalidateQueries({ queryKey: ['goalCategorySettings'] });
            await queryClient.invalidateQueries({ queryKey: ['moods'] });

            toast.success(`Backup importato con successo! (${report.totalProcessed} record ripristinati)`);
            return report;
        } catch (error: any) {
            console.error('Import failed:', error);
            toast.error(`Errore durante l'importazione: ${error.message}`);
            return null;
        } finally {
            setIsImporting(false);
        }
    };

    return { exportCompleteBackup, importCompleteBackup, isExporting, isImporting };
}
