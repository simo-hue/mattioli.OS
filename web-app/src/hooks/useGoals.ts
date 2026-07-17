/* eslint-disable @typescript-eslint/no-explicit-any */
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { Goal, GoalLog, GoalStatus, GoalLogsMap } from '@/types/goals';
import { toast } from 'sonner';
import { getLocalDateKey, isDateInGoalRange } from '@/lib/date-utils';

export function useGoals() {
    const queryClient = useQueryClient();

    // 1. Fetch Goals
    const { data: goals, isLoading: isLoadingGoals, refetch: refetchGoals } = useQuery({
        queryKey: ['goals'],
        queryFn: async () => {
            const { data, error } = await supabase
                .from('goals')
                .select('*')
                .order('display_order', { ascending: true, nullsFirst: false })
                .order('created_at', { ascending: true });

            if (error) {
                toast.error('Errore caricamento obiettivi');
                throw error;
            }
            return data as Goal[];
        },
    });

    // 2. Fetch Logs
    const { data: logs, isLoading: isLoadingLogs } = useQuery({
        queryKey: ['goal_logs'],
        queryFn: async () => {
            let allLogs: GoalLog[] = [];
            let from = 0;
            const step = 1000;
            let keepFetching = true;

            while (keepFetching) {
                const { data, error } = await supabase
                    .from('goal_logs')
                    .select('*')
                    .range(from, from + step - 1);

                if (error) {
                    console.error(error);
                    throw error;
                }

                if (data && data.length > 0) {
                    allLogs = [...allLogs, ...(data as GoalLog[])];
                    if (data.length < step) keepFetching = false;
                    else from += step;
                } else {
                    keepFetching = false;
                }
            }
            return allLogs;
        },
    });

    // Transform logs into a Map
    const logsMap: GoalLogsMap = {};
    if (logs) {
        logs.forEach(log => {
            if (!logsMap[log.date]) logsMap[log.date] = {};
            logsMap[log.date][log.goal_id] = log.status;
        });
    }

    // 3. Actions

    // CREATE GOAL
    const createGoalMutation = useMutation({
        mutationFn: async (newGoal: Partial<Goal>) => {
            const { data: { session } } = await supabase.auth.getSession();
            if (!session) {
                throw new Error('Non sei autenticato. Effettua il login.');
            }

            // Calculate next display_order
            const { data: maxOrderData } = await supabase
                .from('goals')
                .select('display_order')
                .eq('user_id', session.user.id)
                .order('display_order', { ascending: false, nullsFirst: false })
                .limit(1);

            const nextOrder = (maxOrderData && maxOrderData.length > 0 && (maxOrderData[0] as any).display_order)
                ? (maxOrderData[0] as any).display_order + 1
                : 1;

            const { data, error } = await supabase
                .from('goals')
                .insert([{
                    title: newGoal.title!,
                    color: newGoal.color!,
                    start_date: newGoal.start_date || getLocalDateKey(new Date()),
                    user_id: session.user.id,
                    display_order: nextOrder
                }] as any)
                .select()
                .single();

            if (error) throw error;
            return data;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['goals'] });
            toast.success('Obiettivo creato');
        },
        onError: (e: any) => {
            toast.error('Errore creazione: ' + e.message);
        }
    });

    // UPDATE GOAL (title and color only - preserves all historical data)
    const updateGoalMutation = useMutation({
        mutationFn: async ({ id, title, color }: { id: string; title: string; color: string }) => {
            const { data: { session } } = await supabase.auth.getSession();
            if (!session) {
                throw new Error('Non sei autenticato. Effettua il login.');
            }

            const { error } = await (supabase
                .from('goals') as any)
                .update({ title, color })
                .eq('id', id)
                .eq('user_id', session.user.id);

            if (error) throw error;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['goals'] });
            toast.success('Abitudine aggiornata');
        },
        onError: (e: any) => {
            toast.error('Errore aggiornamento: ' + e.message);
        }
    });

    const softDelete = async (goalId: string) => {
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);

        const { error } = await (supabase
            .from('goals') as any)
            .update({ end_date: getLocalDateKey(yesterday) })
            .eq('id', goalId);

        if (error) {
            console.error('Soft delete failed:', error);
            throw error;
        }
    };

    // DELETE GOAL (Smart Delete)
    const deleteGoalMutation = useMutation({
        mutationFn: async (goalId: string) => {
            // 1. Check for logs
            const { count, error: countError } = await supabase
                .from('goal_logs')
                .select('*', { count: 'exact', head: true })
                .eq('goal_id', goalId);

            if (countError) throw countError;

            if (count && count > 0) {
                // 2a. Soft Delete (Archive) if logs exist
                await softDelete(goalId);
            } else {
                try {
                    // 2b. Hard Delete if no logs
                    const { error } = await supabase
                        .from('goals')
                        .delete()
                        .eq('id', goalId);

                    if (error) {
                        // If generic error, fallback to soft delete
                        console.warn('Hard delete failed, falling back to soft delete', error);
                        await softDelete(goalId);
                    }
                } catch (e) {
                    console.warn('Hard delete exception, falling back to soft delete', e);
                    await softDelete(goalId);
                }
            }
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['goals'] });
            toast.success('Obiettivo eliminato');
        },
        onError: (e: any) => {
            toast.error('Errore eliminazione: ' + e.message);
        }
    });

    // HARD RESET
    const resetAllDataMutation = useMutation({
        mutationFn: async () => {
            const { data: { session } } = await supabase.auth.getSession();
            if (!session) throw new Error('Not authenticated');

            // Delete all logs first (to be safe regardless of cascade)
            const { error: logsError } = await supabase
                .from('goal_logs')
                .delete()
                .eq('user_id', session.user.id);

            if (logsError) throw logsError;

            // Then delete goals
            const { error } = await supabase
                .from('goals')
                .delete()
                .eq('user_id', session.user.id);

            if (error) throw error;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['goals'] });
            queryClient.invalidateQueries({ queryKey: ['goal_logs'] });
            toast.success('Reset completo effettuato');
        },
        onError: (e: any) => {
            toast.error('Errore reset: ' + e.message);
        }
    });

    const activeGoals = (goals || []).filter(g => !g.end_date || g.end_date >= getLocalDateKey(new Date()));

    // TOGGLE STATUS
    const toggleLogMutation = useMutation({
        mutationFn: async ({ goalId, date, currentStatus }: { goalId: string, date: Date, currentStatus: GoalStatus }) => {
            const dateStr = getLocalDateKey(date);
            const { data: { session } } = await supabase.auth.getSession();

            // Fetch goal to verify range
            const { data: goal, error: goalError } = await supabase
                .from('goals')
                .select('start_date, end_date')
                .eq('id', goalId)
                .single();

            if (goalError || !goal) throw goalError || new Error('Goal not found');
            const goalData = goal as any;

            if (!isDateInGoalRange(dateStr, goalData.start_date, goalData.end_date)) {
                throw new Error('Impossibile modificare un obiettivo fuori dal suo periodo di validità.');
            }

            // Logic: None -> Done -> Missed -> None
            let nextStatus: GoalStatus = 'done';
            if (currentStatus === 'done') nextStatus = 'missed';
            else if (currentStatus === 'missed') nextStatus = null;

            if (nextStatus === null) {
                // Delete log
                const { error } = await supabase
                    .from('goal_logs')
                    .delete()
                    .eq('goal_id', goalId)
                    .eq('date', dateStr);
                if (error) throw error;
            } else {
                // Upsert log
                const { error } = await supabase
                    .from('goal_logs')
                    .upsert({
                        goal_id: goalId,
                        date: dateStr,
                        status: nextStatus,
                        user_id: session?.user.id
                    } as any, { onConflict: 'goal_id, date' });
                if (error) throw error;
            }
            return { goalId, dateStr, nextStatus };
        },
        // Optimistic Update
        onMutate: async ({ goalId, date, currentStatus }) => {
            await queryClient.cancelQueries({ queryKey: ['goal_logs'] });
            const previousLogs = queryClient.getQueryData<GoalLog[]>(['goal_logs']);
            const dateStr = getLocalDateKey(date);

            let nextStatus: GoalStatus = 'done';
            if (currentStatus === 'done') nextStatus = 'missed';
            else if (currentStatus === 'missed') nextStatus = null;

            queryClient.setQueryData<GoalLog[]>(['goal_logs'], (old) => {
                if (!old) return [];
                const filtered = old.filter(l => !(l.goal_id === goalId && l.date === dateStr));
                if (nextStatus) {
                    return [...filtered, {
                        id: 'temp-' + Date.now(),
                        goal_id: goalId,
                        date: dateStr,
                        status: nextStatus,
                        created_at: '',
                        updated_at: ''
                    }];
                }
                return filtered;
            });

            return { previousLogs };
        },
        onError: (err, newTodo, context) => {
            queryClient.setQueryData(['goal_logs'], context?.previousLogs);
            toast.error('Errore aggiornamento');
        },
        onSettled: () => {
            queryClient.invalidateQueries({ queryKey: ['goal_logs'] });
        },
    });

    // UPDATE ORDER (for drag & drop)
    const updateOrderMutation = useMutation({
        mutationFn: async (reorderedGoals: { id: string; display_order: number }[]) => {
            const { data: { session } } = await supabase.auth.getSession();
            if (!session) {
                throw new Error('Non sei autenticato. Effettua il login.');
            }

            // Bulk update using Promise.all
            const updates = reorderedGoals.map(async ({ id, display_order }) => {
                const { error } = await (supabase
                    .from('goals') as any)
                    .update({ display_order })
                    .eq('id', id)
                    .eq('user_id', session.user.id);

                if (error) {
                    throw error;
                }

                return { id, display_order };
            });

            await Promise.all(updates);
        },
        onSuccess: async () => {
            await queryClient.invalidateQueries({ queryKey: ['goals'] });
            // Explicitly refetch to ensure we get the new order
            setTimeout(() => {
                queryClient.refetchQueries({ queryKey: ['goals'] });
            }, 100);
            toast.success('Ordine salvato');
        },
        onError: (e: any) => {
            toast.error('Errore salvataggio ordine: ' + e.message);
        }
    });

    return {
        goals: activeGoals,
        allGoals: goals || [],
        logs: logsMap,
        rawLogs: logs || [],
        isLoading: isLoadingGoals || isLoadingLogs,
        createGoal: createGoalMutation.mutate,
        updateGoal: updateGoalMutation.mutate,
        isUpdating: updateGoalMutation.isPending,
        updateOrder: updateOrderMutation.mutate,
        isUpdatingOrder: updateOrderMutation.isPending,
        deleteGoal: deleteGoalMutation.mutate,
        isDeleting: deleteGoalMutation.isPending,
        resetAllData: resetAllDataMutation.mutate,
        isResetting: resetAllDataMutation.isPending,
        toggleGoal: async (date: Date, goalId: string) => {
            const dateStr = getLocalDateKey(date);
            const currentStatus = logsMap[dateStr]?.[goalId] || null;
            toggleLogMutation.mutate({ goalId, date, currentStatus });
        }
    };
}
