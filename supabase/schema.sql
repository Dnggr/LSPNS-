-- ============================================================
-- LSPNS - Local Safety and Public Notice System
-- Paste this entire file into Supabase SQL Editor and run it
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================================
-- USERS TABLE (extends Supabase auth.users)
-- ============================================================
create table public.users (
  id uuid references auth.users(id) on delete cascade primary key,
  full_name text not null,
  role text not null default 'resident' check (role in ('resident', 'official', 'admin')),
  phone text,
  created_at timestamptz default now()
);

-- ============================================================
-- REPORTS TABLE
-- ============================================================
create table public.reports (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.users(id) on delete set null,
  type text not null check (type in ('street_light', 'road_damage', 'hazard', 'announcement')),
  description text,
  lat double precision not null,
  lng double precision not null,
  photo_url text,
  status text not null default 'pending' check (status in ('pending', 'in_progress', 'resolved')),
  assigned_to uuid references public.users(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- STATUS LOGS TABLE (audit trail)
-- ============================================================
create table public.status_logs (
  id uuid default uuid_generate_v4() primary key,
  report_id uuid references public.reports(id) on delete cascade not null,
  changed_by uuid references public.users(id) on delete set null,
  old_status text,
  new_status text not null,
  note text,
  changed_at timestamptz default now()
);

-- ============================================================
-- AUTO-UPDATE updated_at ON REPORTS
-- ============================================================
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger reports_updated_at
  before update on public.reports
  for each row execute function update_updated_at();

-- ============================================================
-- AUTO-LOG status changes
-- ============================================================
create or replace function log_status_change()
returns trigger as $$
begin
  if old.status is distinct from new.status then
    insert into public.status_logs (report_id, changed_by, old_status, new_status)
    values (new.id, auth.uid(), old.status, new.status);
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger reports_status_log
  after update on public.reports
  for each row execute function log_status_change();

-- ============================================================
-- AUTO-CREATE user profile on signup
-- ============================================================
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'User'),
    coalesce(new.raw_user_meta_data->>'role', 'resident')
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.users enable row level security;
alter table public.reports enable row level security;
alter table public.status_logs enable row level security;

-- Users: can read own profile; officials/admins can read all
create policy "Users can read own profile"
  on public.users for select
  using (auth.uid() = id);

create policy "Officials can read all users"
  on public.users for select
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role in ('official', 'admin')
    )
  );

create policy "Users can update own profile"
  on public.users for update
  using (auth.uid() = id);

-- Reports: residents see own; officials/admins see all
create policy "Residents can insert reports"
  on public.reports for insert
  with check (auth.uid() = user_id);

create policy "Residents can read own reports"
  on public.reports for select
  using (auth.uid() = user_id);

create policy "Officials can read all reports"
  on public.reports for select
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role in ('official', 'admin')
    )
  );

create policy "Officials can update reports"
  on public.reports for update
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role in ('official', 'admin')
    )
  );

-- Status logs: residents see logs for own reports; officials see all
create policy "Residents can read own report logs"
  on public.status_logs for select
  using (
    exists (
      select 1 from public.reports r
      where r.id = report_id and r.user_id = auth.uid()
    )
  );

create policy "Officials can read all logs"
  on public.status_logs for select
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role in ('official', 'admin')
    )
  );

-- ============================================================
-- STORAGE BUCKET for report photos
-- Run this AFTER creating the bucket named "report-photos" in
-- the Supabase dashboard under Storage > New bucket (public)
-- ============================================================
insert into storage.buckets (id, name, public)
values ('report-photos', 'report-photos', true)
on conflict do nothing;

create policy "Anyone authenticated can upload photos"
  on storage.objects for insert
  with check (bucket_id = 'report-photos' and auth.role() = 'authenticated');

create policy "Photos are publicly readable"
  on storage.objects for select
  using (bucket_id = 'report-photos');

-- ============================================================
-- SEED: Create a test official account
-- After running this, go to Supabase Auth > Users > Invite user
-- with email: official@lspns.test, then update role below:
-- UPDATE public.users SET role = 'official' WHERE full_name = 'Test Official';
-- ============================================================