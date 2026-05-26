create table if not exists reluctants (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references auth.users(id),
  image_url text not null,
  district text not null,
  is_anonymous boolean default false,
  created_at timestamp with time zone default now(),
  expires_at timestamp with time zone default (now() + interval '24 hours')
);

create table if not exists reluctant_views (
  id uuid default gen_random_uuid() primary key,
  reluctant_id uuid references reluctants(id),
  viewer_id uuid references auth.users(id),
  viewed_at timestamp with time zone default now(),
  unique(reluctant_id, viewer_id)
);

create table if not exists reluctant_reactions (
  id uuid default gen_random_uuid() primary key,
  reluctant_id uuid references reluctants(id),
  sender_id uuid references auth.users(id),
  reaction text,
  message text,
  created_at timestamp with time zone default now()
);

alter publication supabase_realtime add table reluctants;
alter publication supabase_realtime add table reluctant_reactions;
