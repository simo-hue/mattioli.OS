export type GoalStatus = 'done' | 'missed' | 'skipped' | null;

// Auto-verified habits (iOS-only verification). The web app never verifies —
// it only displays these read-only. Wire values mirror the Flutter clients.
export type VerificationProvider = 'healthkit' | 'screentime';
export type VerificationComparator = 'gte' | 'lte';

export interface Goal {
    id: string;
    user_id: string;
    title: string;
    description?: string;
    color: string;
    icon?: string;
    start_date: string; // ISO Date "YYYY-MM-DD"
    end_date?: string | null; // ISO Date "YYYY-MM-DD"
    frequency_days?: number[]; // 1-7 (Mon-Sun)
    display_order?: number; // Custom order position
    // Auto-verification rule (all null/absent => ordinary manual habit).
    verify_provider?: VerificationProvider | null;
    verify_metric?: string | null; // template key, e.g. "steps", "screen_time_total"
    verify_comparator?: VerificationComparator | null;
    verify_threshold?: number | null;
    verify_unit?: string | null; // "count" | "minutes" | "hours" | "kilocalories" | "kilometers"
    created_at: string;
    updated_at: string;
}

export interface GoalLog {
    id: string;
    goal_id: string;
    date: string; // ISO Date "YYYY-MM-DD"
    status: GoalStatus;
    notes?: string;
    value?: number;
    created_at: string;
    updated_at: string;
}

export interface GoalsMap {
    [id: string]: Goal;
}

export interface GoalLogsMap {
    [date: string]: {
        [goalId: string]: GoalStatus;
    };
}
