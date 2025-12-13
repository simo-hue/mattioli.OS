export type GoalStatus = 'done' | 'missed' | 'skipped' | null;

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
