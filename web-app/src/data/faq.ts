/**
 * The FAQ content, in one place.
 *
 * Lives here rather than inside FAQ.tsx so the page and the FAQPage structured
 * data read the same array. The build script used to re-parse the component
 * source with a regex to recover these pairs — which worked, but meant the schema
 * would drift the moment the component's formatting changed.
 *
 * Icons stay in the page: they are presentation, and importing lucide components
 * here would pull them into every route that only wants the questions.
 */

export interface FaqEntry {
  q: string;
  a: string;
}

export interface FaqCategory {
  category: string;
  questions: FaqEntry[];
}

export const faqData: FaqCategory[] = [
    {
        category: "Philosophy & General",
        questions: [
            { q: "What is Mattioli.OS?", a: "It's a complete operating system for personal growth. It's not just a habit tracker, but an integrated suite for managing daily habits, long-term goals and performance analysis." },
            { q: "Why 'OS' (Operating System)?", a: "Because it aims to replace the fragmented infrastructure we usually use (scattered notes, multiple apps, Excel sheets) with a single centralized and consistent system to manage your life." },
            { q: "Is it really free?", a: "Yes, 100%. It's an Open Source project released under the MIT license. Your data is yours, there's no premium subscription." },
            { q: "How is it different from Notion or Todoist?", a: "Mattioli.OS is 'opinionated'. Notion is flexible but requires hours for setup. Todoist is focused on lists. This system is built specifically for discipline and quantitative data analysis, ready to use." },
            { q: "What is the core philosophy?", a: "It's based on 'Atomic Habits' by James Clear: 'We don't rise to the level of our goals, we fall to the level of our systems.' The focus is on reducing friction and visualizing progress." },
            { q: "Do I need to create an account?", a: "Yes, the system uses Supabase Auth to ensure your data is secure, encrypted and accessible only to you. The account is free." },
            { q: "Who is the developer?", a: "I'm Simone Mattioli, a developer passionate about productivity and data visualization. I initially built this tool for myself." },
        ]
    },
    {
        category: "Daily Protocol",
        questions: [
            { q: "What is the 'Daily Protocol'?", a: "It's your list of non-negotiable daily habits. The heart of the system for building consistency." },
            { q: "How does the 'Tri-State' logic work?", a: "Each habit can have 3 states: 'Done' (completed, green), 'Missed' (failed, red), 'Skipped' (legitimately skipped, gray). This offers more nuance than simple yes/no." },
            { q: "What's the difference between Missed and Skipped?", a: "'Missed' penalizes your streak and statistics (you failed). 'Skipped' is neutral (e.g., you were sick or on vacation), it doesn't break the streak but doesn't contribute to the score." },
            { q: "How do I delete a habit?", a: "If the habit has historical data, it gets 'archived' (Soft Delete) to not lose past statistics. If it has no data, it gets permanently deleted." },
            { q: "Can I customize the colors?", a: "Absolutely. Each habit can have a specific color to help you visually group them (e.g., Health = Green, Work = Blue)." },
            { q: "What is a 'Streak'?", a: "It's the number of consecutive days you've completed a habit without 'Missed'. 'Skipped' keeps the streak frozen." },
            { q: "Can I set habits for specific days only?", a: "Yes, you can define the frequency (e.g., Mon, Wed, Fri). On other days the habit won't appear in your daily list." },
            { q: "Can I track numeric values?", a: "Yes, you can enable quantitative tracking (e.g., '2 liters of water', '10 pages read') in addition to completed status." },
        ]
    },
    {
        category: "Macro Goals & Vision",
        questions: [
            { q: "What are Macro Goals?", a: "These are long-term goals structured hierarchically: Yearly, Quarterly, Monthly and Weekly." },
            { q: "How do I visualize my long-term progress?", a: "There's a dedicated dashboard ('Map') with radar charts, completion trends and category analysis to see if you're balancing your life well." },
            { q: "What is the 'Memento Mori' calendar?", a: "A visualization of your life in weeks (from presumed birth to statistical death). It serves to create urgency and give value to time." },
            { q: "Can I see the history of past years?", a: "Yes, the 'All-Time' dashboard allows you to navigate through data from all years you've used the system, with aggregated KPIs." },
            { q: "Is there a limit to the number of goals?", a: "Technically no. The system handles efficient pagination even for thousands of records, but for your sanity we recommend focusing on a few priorities." },
        ]
    },
    {
        category: "AI Coach & Privacy",
        questions: [
            { q: "How does the AI Coach work?", a: "It analyzes your data (habits, mood, goals) and generates weekly reports with personalized advice. It works like a virtual mental coach." },
            { q: "Is my data sent to OpenAI/Google?", a: "NO. By default the system is designed to use 'Local LLM' (Ollama). Data is processed locally on your machine. Privacy first." },
            { q: "What does 'Local LLM' mean?", a: "It means the artificial intelligence model (e.g., Llama 3, Mistral) runs on your computer, not on a remote server. No data leaves your network." },
            { q: "How do I configure Ollama?", a: "You need to download Ollama from the official website, install a model (e.g., `ollama run llama3`) and make sure the server is active on port 11434." },
            { q: "Can I use the system without AI?", a: "Certainly. The AI Coach is an optional module. If you don't configure it or disable it in settings, the rest of the app works perfectly." },
            { q: "Does the AI read my personal notes?", a: "Only if you explicitly allow it to generate correlations between your mood and your performance." },
        ]
    },
    {
        category: "Tech & Data",
        questions: [
            { q: "Where is the data saved?", a: "On Supabase, an open source and secure PostgreSQL database. You are the only owner of your data through authentication." },
            { q: "Can I make a backup?", a: "Yes. There's a 'Complete Backup' function that downloads a ZIP archive containing all your data in JSON format, organized by tables." },
            { q: "Can I import/export data?", a: "Yes, the backup system supports both complete export and import, useful for migrating or securing information." },
            { q: "Is there a mobile app?", a: "Yes! Mattioli.OS is available as a native iOS app in the Apple App Store. The companion web dashboard is also fully responsive and installable as a Progressive Web App (PWA) on any mobile home screen." },
            { q: "What is the tech stack?", a: "React 18, Vite, TypeScript, Tailwind CSS, shadcn/ui, Supabase, TanStack Query, Recharts." },
            { q: "Can I self-host the database?", a: "Yes, since Supabase is open source, you can host your own Docker instance if you have the technical skills to do so." },
        ]
    },
    {
        category: "Troubleshooting & Support",
        questions: [
            { q: "I found a bug, what do I do?", a: "Open an issue on GitHub. The project is actively maintained and community contributions are welcome." },
            { q: "Why isn't the AI responding?", a: "Verify that Ollama is running (`ollama serve`) and that the selected model is downloaded. Also check that the browser isn't blocking calls to localhost (CORS)." },
            { q: "The site seems slow with lots of data?", a: "We've implemented recursive pagination and virtual scrolling. If you notice slowdowns above 100k records, let us know." },
            { q: "How do I update to the new version?", a: "If you use the web version, simply refresh the page. If you cloned the repo, do `git pull` and `npm run build`." },
        ]
    }
];

/** Flattened, in page order — what the FAQPage schema needs. */
export const faqPairs: FaqEntry[] = faqData.flatMap((c) => c.questions);
