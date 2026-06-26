create extension if not exists pgcrypto;

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null default '幸福小家',
  invite_code text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  created_at timestamptz not null default now(),
  primary key (household_id, user_id)
);

create table if not exists public.cashflow_books (
  household_id uuid primary key references public.households(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.cashflow_books enable row level security;

drop policy if exists "authenticated can create households" on public.households;
create policy "authenticated can create households"
on public.households for insert
to authenticated
with check (true);

drop policy if exists "authenticated can read invite targets" on public.households;
create policy "authenticated can read invite targets"
on public.households for select
to authenticated
using (true);

drop policy if exists "members can read memberships" on public.household_members;
create policy "members can read memberships"
on public.household_members for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "users can join households as themselves" on public.household_members;
create policy "users can join households as themselves"
on public.household_members for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "members can read household book" on public.cashflow_books;
create policy "members can read household book"
on public.cashflow_books for select
to authenticated
using (
  exists (
    select 1 from public.household_members hm
    where hm.household_id = cashflow_books.household_id
      and hm.user_id = auth.uid()
  )
);

drop policy if exists "members can create household book" on public.cashflow_books;
create policy "members can create household book"
on public.cashflow_books for insert
to authenticated
with check (
  exists (
    select 1 from public.household_members hm
    where hm.household_id = cashflow_books.household_id
      and hm.user_id = auth.uid()
  )
);

drop policy if exists "members can update household book" on public.cashflow_books;
create policy "members can update household book"
on public.cashflow_books for update
to authenticated
using (
  exists (
    select 1 from public.household_members hm
    where hm.household_id = cashflow_books.household_id
      and hm.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.household_members hm
    where hm.household_id = cashflow_books.household_id
      and hm.user_id = auth.uid()
  )
);

create or replace function public.set_cashflow_book_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_cashflow_book_updated_at on public.cashflow_books;
create trigger set_cashflow_book_updated_at
before update on public.cashflow_books
for each row execute function public.set_cashflow_book_updated_at();

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cashflow_books'
  ) then
    alter publication supabase_realtime add table public.cashflow_books;
  end if;
end;
$$;
