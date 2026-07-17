import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';

export type SystemStatus = 'active' | 'offline' | 'error';

export const useSystemStatus = () => {
    const [status, setStatus] = useState<SystemStatus>('active');
    const [latency, setLatency] = useState<number | null>(null);

    useEffect(() => {
        const checkStatus = async () => {
            if (!navigator.onLine) {
                setStatus('offline');
                return;
            }

            const start = performance.now();
            try {
                const { error } = await supabase.from('goals').select('id', { count: 'exact', head: true });

                if (error) {
                    console.error("Supabase health check failed:", error);
                    setStatus('error');
                } else {
                    setStatus('active');
                    setLatency(Math.round(performance.now() - start));
                }
            } catch (err) {
                console.error("Supabase connection error:", err);
                setStatus('error');
            }
        };

        // Initial check
        checkStatus();

        // Listen for online/offline events
        window.addEventListener('online', checkStatus);
        window.addEventListener('offline', () => setStatus('offline'));

        // Periodic check (every 30s)
        const interval = setInterval(checkStatus, 30000);

        return () => {
            window.removeEventListener('online', checkStatus);
            window.removeEventListener('offline', () => setStatus('offline'));
            clearInterval(interval);
        };
    }, []);

    return { status, latency };
};
