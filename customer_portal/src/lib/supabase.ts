import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://kpgkoltwzorznfshwwiv.supabase.co';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtwZ2tvbHR3em9yem5mc2h3d2l2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2NzIwNTcsImV4cCI6MjEwMDI0ODA1N30.0ASHQQ6XM8QXkwaiM3xXVk1vzPYEADQOzqzWu4ANrNk';

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false,
  },
});
