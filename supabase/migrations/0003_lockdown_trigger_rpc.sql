-- The new-user bootstrap is a trigger-only function; it must never be
-- callable directly as a PostgREST RPC by anon/authenticated.
revoke execute on function public.synapse_handle_new_user() from anon, authenticated, public;
