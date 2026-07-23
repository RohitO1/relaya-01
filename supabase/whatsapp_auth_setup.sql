-- Create whatsapp_otps table to store generated OTPs
create table if not exists public.whatsapp_otps (
    phone text primary key,
    otp_code text not null,
    expires_at timestamp with time zone not null,
    created_at timestamp with time zone default now() not null
);

-- Enable Row Level Security (RLS)
alter table public.whatsapp_otps enable row level security;

-- Do not create any public RLS policies. This ensures that the table is only
-- accessible via the service_role key (which bypasses RLS) used by the Edge Functions.
-- This keeps the OTP codes completely secure from direct client queries.
comment on table public.whatsapp_otps is 'Temporarily stores verification codes for Meta WhatsApp OTP login.';
