export interface DailyMood {
    id: string;
    user_id: string;
    date: string; // ISO Date "YYYY-MM-DD"
    mood_score: number; // 1-10
    energy_score: number; // 1-10
    note?: string;
    created_at: string;
    updated_at: string;
}
