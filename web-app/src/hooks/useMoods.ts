import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { DailyMood } from "@/types/mood";
import { toast } from "sonner";
import { format } from "date-fns";

export const useMoods = () => {
    return useQuery({
        queryKey: ["moods"],
        queryFn: async () => {
            const { data, error } = await supabase
                .from("daily_moods")
                .select("*")
                .order("date", { ascending: false });

            if (error) {
                console.error("Error fetching moods:", error);
                throw error;
            }

            return data as DailyMood[];
        },
    });
};

export const useTodaysMood = () => {
    const today = format(new Date(), "yyyy-MM-dd");
    return useQuery({
        queryKey: ["moods", today],
        queryFn: async () => {
            const { data, error } = await supabase
                .from("daily_moods")
                .select("*")
                .eq("date", today)
                .maybeSingle();

            if (error) {
                console.error("Error fetching today's mood:", error);
                throw error;
            }

            return data as DailyMood | null;
        },
    });
};

export const useLogMood = () => {
    const queryClient = useQueryClient();

    return useMutation({
        mutationFn: async (mood: Omit<DailyMood, "id" | "user_id" | "created_at" | "updated_at">) => {
            const { data: { user } } = await supabase.auth.getUser();
            if (!user) throw new Error("No user found");

            const { data, error } = await supabase
                .from("daily_moods")
                .upsert({
                    ...mood,
                    user_id: user.id
                }, {
                    onConflict: "user_id,date"
                })
                .select()
                .single();

            if (error) throw error;
            return data;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ["moods"] });
            toast.success("Mood & Energy logged successfully!");
        },
        onError: (error) => {
            console.error("Error logging mood:", error);
            toast.error("Failed to log mood.");
        },
    });
};
