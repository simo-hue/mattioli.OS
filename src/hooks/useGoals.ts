import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { Goal, GoalLog, GoalStatus, GoalLogsMap } from '@/types/goals';
import { toast } from 'sonner';

export function useGoals() {
    const queryClient = useQueryClient();

    // 1. Fetch Goals
    const { data: goals, isLoading: isLoadingGoals } = useQuery({
        queryKey: ['goals'],
        queryFn: async () => {
            const { data, error } = await supabase
                .from('goals')
                .select('*')
                .order('created_at', { ascending: true });

            if (error) {
                toast.error('Errore caricamento obiettivi');
                throw error;
            }
            return data as Goal[];
        },
    });

    // 2. Fetch Logs (We fetch ALL logs for simplicity for now, or could range constrain later)
    const { data: logs, isLoading: isLoadingLogs } = useQuery({
        queryKey: ['goal_logs'],
        queryFn: async () => {
            const { data, error } = await supabase
                .from('goal_logs')
                .select('*');

            if (error) {
                console.error(error);
                return [];
            }
            return data as GoalLog[];
        },
    });

    // Transform logs into a Map for easy O(1) access in UI [date][goalId]
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

            const { data, error } = await supabase
                .from('goals')
                .insert([{
                    title: newGoal.title!,
                    color: newGoal.color!,
                    start_date: newGoal.start_date || new Date().toISOString().split('T')[0],
                    user_id: session.user.id
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

    // DELETE GOAL
    const deleteGoalMutation = useMutation({
        mutationFn: async (goalId: string) => {
            const { error } = await supabase
                .from('goals')
                .delete()
                .eq('id', goalId);
            if (error) throw error;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['goals'] });
            toast.success('Obiettivo eliminato');
        },
    });

    // TOGGLE STATUS
    const toggleLogMutation = useMutation({
        mutationFn: async ({ goalId, date, currentStatus }: { goalId: string, date: Date, currentStatus: GoalStatus }) => {
            const dateStr = date.toISOString().split('T')[0];
            const { data: { session } } = await supabase.auth.getSession(); // Get session for user_id

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
                        user_id: session?.user.id // Add user_id if session exists (it should)
                    } as any, { onConflict: 'goal_id, date' });
                if (error) throw error;
            }
            return { goalId, dateStr, nextStatus };
        },
        // Optimistic Update
        onMutate: async ({ goalId, date, currentStatus }) => {
            await queryClient.cancelQueries({ queryKey: ['goal_logs'] });
            const previousLogs = queryClient.getQueryData<GoalLog[]>(['goal_logs']);
            const dateStr = date.toISOString().split('T')[0];

            let nextStatus: GoalStatus = 'done';
            if (currentStatus === 'done') nextStatus = 'missed';
            else if (currentStatus === 'missed') nextStatus = null;

            queryClient.setQueryData<GoalLog[]>(['goal_logs'], (old) => {
                if (!old) return [];
                // Remove existing
                const filtered = old.filter(l => !(l.goal_id === goalId && l.date === dateStr));
                if (nextStatus) {
                    // Add new
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

    return {
        goals: goals || [],
        logs: logsMap, // Returns the convenient Map
        rawLogs: logs || [], // Returns raw array if needed
        isLoading: isLoadingGoals || isLoadingLogs,
        createGoal: createGoalMutation.mutate,
        deleteGoal: deleteGoalMutation.mutate,
        toggleGoal: (date: Date, goalId: string) => {
            const dateStr = date.toISOString().split('T')[0];
            const currentStatus = logsMap[dateStr]?.[goalId] || null;
            toggleLogMutation.mutate({ goalId, date, currentStatus });
        }
    };
}
