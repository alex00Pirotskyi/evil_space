-- Evil Space operations foundation.
-- Apply this to a dedicated Supabase project before enabling /admin.

create extension if not exists pgcrypto;

do $$ begin
  create type public.app_role as enum ('viewer', 'staff', 'manager', 'owner');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.customer_status as enum ('active', 'paused', 'ended');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.pass_type as enum ('day', 'month');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.payment_status as enum ('pending', 'paid', 'refunded', 'void');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.purchase_state as enum ('needed', 'approved', 'bought', 'cancelled');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.purchase_priority as enum ('low', 'normal', 'high');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.notification_audience as enum ('all_staff', 'managers', 'owners');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.delivery_state as enum ('queued', 'delivered', 'failed', 'read');
exception when duplicate_object then null;
end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  role public.app_role not null default 'viewer',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.site_state (
  singleton boolean primary key default true check (singleton),
  total_desks integer not null default 10 check (total_desks between 1 and 999),
  occupied_desks integer not null default 3 check (
    occupied_desks >= 0 and occupied_desks <= total_desks
  ),
  status_updated_at timestamptz not null default now(),
  day_price_vnd integer not null default 250000 check (day_price_vnd >= 0),
  day_price_label text not null default '250K VND',
  month_price_vnd integer not null default 2500000 check (month_price_vnd >= 0),
  month_price_label text not null default '2.5 MLN VND',
  daily_note jsonb not null default '{"en":"WELCOME TO EVIL SPACE","ru":"ДОБРО ПОЖАЛОВАТЬ В EVIL SPACE","vi":"CHÀO MỪNG ĐẾN EVIL SPACE"}'::jsonb,
  daily_note_date date not null default current_date,
  studio_opening_date date not null default date '2026-10-20',
  studio_is_open boolean not null default false,
  lecture_opening_date date not null default date '2026-10-20',
  lecture_is_open boolean not null default false,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(daily_note) = 'object')
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  display_name text not null check (char_length(trim(display_name)) between 1 and 120),
  phone text,
  email text,
  pass public.pass_type not null,
  desk_label text,
  status public.customer_status not null default 'active',
  starts_on date not null default current_date,
  ends_on date,
  notes text,
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on is null or ends_on >= starts_on)
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete restrict,
  amount_vnd integer not null check (amount_vnd > 0),
  status public.payment_status not null default 'pending',
  due_on date,
  paid_at timestamptz,
  method text check (method is null or method in ('cash', 'bank', 'card', 'other')),
  receipt_reference text,
  notes text,
  verified_by uuid references public.profiles(id) on delete set null,
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'paid' and paid_at is not null) or status <> 'paid')
);

create table if not exists public.purchase_requests (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 1 and 180),
  area text,
  priority public.purchase_priority not null default 'normal',
  state public.purchase_state not null default 'needed',
  estimated_vnd integer check (estimated_vnd is null or estimated_vnd >= 0),
  actual_vnd integer check (actual_vnd is null or actual_vnd >= 0),
  notes text,
  requested_by uuid not null default auth.uid() references public.profiles(id),
  approved_by uuid references public.profiles(id) on delete set null,
  bought_by uuid references public.profiles(id) on delete set null,
  purchased_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((state = 'bought' and purchased_at is not null) or state <> 'bought')
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 1 and 180),
  body text not null default '',
  audience public.notification_audience not null default 'all_staff',
  entity_type text,
  entity_id uuid,
  created_by uuid references public.profiles(id) on delete set null,
  push_dispatched_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  token text not null unique check (char_length(token) between 20 and 4096),
  platform text not null check (platform in ('web', 'android', 'ios')),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_token_id uuid references public.device_tokens(id) on delete set null,
  state public.delivery_state not null default 'queued',
  provider_message_id text,
  error text,
  delivered_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (notification_id, user_id, device_token_id)
);

create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create index if not exists customers_status_idx
  on public.customers (status, ends_on);
create index if not exists payments_customer_idx
  on public.payments (customer_id, created_at desc);
create index if not exists payments_status_due_idx
  on public.payments (status, due_on);
create index if not exists purchases_state_priority_idx
  on public.purchase_requests (state, priority, created_at desc);
create index if not exists notifications_created_idx
  on public.notifications (created_at desc);
create index if not exists deliveries_user_state_idx
  on public.notification_deliveries (user_id, state, created_at desc);
create index if not exists audit_log_entity_idx
  on public.audit_log (entity_type, entity_id, created_at desc);

insert into public.site_state (singleton)
values (true)
on conflict (singleton) do nothing;

create or replace function public.current_app_role()
returns public.app_role
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select role
  from public.profiles
  where id = auth.uid() and active = true
$$;

create or replace function public.is_active_staff()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    public.current_app_role() in ('staff', 'manager', 'owner'),
    false
  )
$$;

create or replace function public.is_manager()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.current_app_role() in ('manager', 'owner'), false)
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.stamp_site_state_actor()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is not null then
    new.updated_by = auth.uid();
  end if;
  if old.total_desks is distinct from new.total_desks
     or old.occupied_desks is distinct from new.occupied_desks then
    new.status_updated_at = now();
  end if;
  return new;
end;
$$;

create or replace function public.normalize_payment()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' and auth.uid() is not null then
    new.created_by = auth.uid();
  elsif tg_op = 'UPDATE' then
    new.created_by = old.created_by;
  end if;

  if new.status = 'paid' and (tg_op = 'INSERT' or old.status <> 'paid') then
    new.paid_at = coalesce(new.paid_at, now());
    if auth.uid() is not null then
      new.verified_by = auth.uid();
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.normalize_purchase()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' and auth.uid() is not null then
    new.requested_by = auth.uid();
  elsif tg_op = 'UPDATE' then
    new.requested_by = old.requested_by;
  end if;

  if tg_op = 'UPDATE' and old.state is distinct from new.state then
    if new.state = 'approved' and auth.uid() is not null then
      new.approved_by = auth.uid();
    elsif new.state = 'bought' then
      new.purchased_at = coalesce(new.purchased_at, now());
      if auth.uid() is not null then
        new.bought_by = auth.uid();
      end if;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.write_audit_log()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  old_json jsonb;
  new_json jsonb;
  record_id uuid;
begin
  old_json := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
  new_json := case when tg_op = 'DELETE' then null else to_jsonb(new) end;
  record_id := coalesce(
    nullif(new_json ->> 'id', '')::uuid,
    nullif(old_json ->> 'id', '')::uuid
  );

  insert into public.audit_log (
    actor_id,
    action,
    entity_type,
    entity_id,
    before_data,
    after_data
  ) values (
    auth.uid(),
    lower(tg_op),
    tg_table_name,
    record_id,
    old_json,
    new_json
  );
  return coalesce(new, old);
end;
$$;

create or replace function public.emit_payment_notification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status = 'paid' and (tg_op = 'INSERT' or old.status <> 'paid') then
    insert into public.notifications (
      title,
      body,
      audience,
      entity_type,
      entity_id,
      created_by
    ) values (
      'Payment marked paid',
      'A customer payment was verified.',
      'managers',
      'payment',
      new.id,
      auth.uid()
    );
  end if;
  return new;
end;
$$;

create or replace function public.emit_purchase_notification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.notifications (
      title,
      body,
      audience,
      entity_type,
      entity_id,
      created_by
    ) values (
      'Purchase requested',
      new.title,
      'all_staff',
      'purchase_request',
      new.id,
      auth.uid()
    );
  elsif old.state is distinct from new.state then
    insert into public.notifications (
      title,
      body,
      audience,
      entity_type,
      entity_id,
      created_by
    ) values (
      case new.state
        when 'approved' then 'Purchase approved'
        when 'bought' then 'Purchase marked bought'
        when 'cancelled' then 'Purchase cancelled'
        else 'Purchase needed'
      end,
      new.title,
      'all_staff',
      'purchase_request',
      new.id,
      auth.uid()
    );
  end if;
  return new;
end;
$$;

create or replace function public.set_staff_access(
  target_user_id uuid,
  new_role public.app_role,
  new_active boolean
)
returns public.profiles
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  updated_profile public.profiles;
begin
  if public.current_app_role() <> 'owner' then
    raise exception 'Only an owner can change staff access';
  end if;

  update public.profiles
  set role = new_role,
      active = new_active,
      updated_at = now()
  where id = target_user_id
  returning * into updated_profile;

  if updated_profile.id is null then
    raise exception 'Profile not found';
  end if;
  return updated_profile;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

drop trigger if exists site_state_touch_updated_at on public.site_state;
create trigger site_state_touch_updated_at
  before update on public.site_state
  for each row execute function public.touch_updated_at();

drop trigger if exists site_state_stamp_actor on public.site_state;
create trigger site_state_stamp_actor
  before update on public.site_state
  for each row execute function public.stamp_site_state_actor();

drop trigger if exists customers_touch_updated_at on public.customers;
create trigger customers_touch_updated_at
  before update on public.customers
  for each row execute function public.touch_updated_at();

drop trigger if exists payments_touch_updated_at on public.payments;
create trigger payments_touch_updated_at
  before update on public.payments
  for each row execute function public.touch_updated_at();

drop trigger if exists payments_normalize on public.payments;
create trigger payments_normalize
  before insert or update on public.payments
  for each row execute function public.normalize_payment();

drop trigger if exists purchases_touch_updated_at on public.purchase_requests;
create trigger purchases_touch_updated_at
  before update on public.purchase_requests
  for each row execute function public.touch_updated_at();

drop trigger if exists purchases_normalize on public.purchase_requests;
create trigger purchases_normalize
  before insert or update on public.purchase_requests
  for each row execute function public.normalize_purchase();

drop trigger if exists deliveries_touch_updated_at on public.notification_deliveries;
create trigger deliveries_touch_updated_at
  before update on public.notification_deliveries
  for each row execute function public.touch_updated_at();

drop trigger if exists profiles_audit on public.profiles;
create trigger profiles_audit
  after insert or update or delete on public.profiles
  for each row execute function public.write_audit_log();

drop trigger if exists site_state_audit on public.site_state;
create trigger site_state_audit
  after update on public.site_state
  for each row execute function public.write_audit_log();

drop trigger if exists customers_audit on public.customers;
create trigger customers_audit
  after insert or update or delete on public.customers
  for each row execute function public.write_audit_log();

drop trigger if exists payments_audit on public.payments;
create trigger payments_audit
  after insert or update or delete on public.payments
  for each row execute function public.write_audit_log();

drop trigger if exists purchases_audit on public.purchase_requests;
create trigger purchases_audit
  after insert or update or delete on public.purchase_requests
  for each row execute function public.write_audit_log();

drop trigger if exists payments_notify on public.payments;
create trigger payments_notify
  after insert or update of status on public.payments
  for each row execute function public.emit_payment_notification();

drop trigger if exists purchases_notify on public.purchase_requests;
create trigger purchases_notify
  after insert or update of state on public.purchase_requests
  for each row execute function public.emit_purchase_notification();

alter table public.profiles enable row level security;
alter table public.site_state enable row level security;
alter table public.customers enable row level security;
alter table public.payments enable row level security;
alter table public.purchase_requests enable row level security;
alter table public.notifications enable row level security;
alter table public.device_tokens enable row level security;
alter table public.notification_deliveries enable row level security;
alter table public.audit_log enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_manager());

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid() and active = true)
  with check (id = auth.uid() and active = true);

drop policy if exists site_state_public_read on public.site_state;
create policy site_state_public_read on public.site_state
  for select to anon, authenticated
  using (true);

drop policy if exists site_state_staff_update on public.site_state;
create policy site_state_staff_update on public.site_state
  for update to authenticated
  using (public.is_active_staff())
  with check (public.is_active_staff());

drop policy if exists customers_staff_select on public.customers;
create policy customers_staff_select on public.customers
  for select to authenticated using (public.is_active_staff());

drop policy if exists customers_staff_insert on public.customers;
create policy customers_staff_insert on public.customers
  for insert to authenticated with check (
    public.is_active_staff() and created_by = auth.uid()
  );

drop policy if exists customers_staff_update on public.customers;
create policy customers_staff_update on public.customers
  for update to authenticated
  using (public.is_active_staff())
  with check (public.is_active_staff());

drop policy if exists customers_owner_delete on public.customers;
create policy customers_owner_delete on public.customers
  for delete to authenticated
  using (public.current_app_role() = 'owner');

drop policy if exists payments_staff_select on public.payments;
create policy payments_staff_select on public.payments
  for select to authenticated using (public.is_active_staff());

drop policy if exists payments_staff_insert on public.payments;
create policy payments_staff_insert on public.payments
  for insert to authenticated with check (
    public.is_active_staff() and created_by = auth.uid()
  );

drop policy if exists payments_manager_update on public.payments;
create policy payments_manager_update on public.payments
  for update to authenticated
  using (public.is_manager())
  with check (public.is_manager());

drop policy if exists payments_owner_delete on public.payments;
create policy payments_owner_delete on public.payments
  for delete to authenticated
  using (public.current_app_role() = 'owner');

drop policy if exists purchases_staff_select on public.purchase_requests;
create policy purchases_staff_select on public.purchase_requests
  for select to authenticated using (public.is_active_staff());

drop policy if exists purchases_staff_insert on public.purchase_requests;
create policy purchases_staff_insert on public.purchase_requests
  for insert to authenticated with check (
    public.is_active_staff() and requested_by = auth.uid()
  );

drop policy if exists purchases_staff_update on public.purchase_requests;
create policy purchases_staff_update on public.purchase_requests
  for update to authenticated
  using (public.is_active_staff())
  with check (public.is_active_staff());

drop policy if exists purchases_owner_delete on public.purchase_requests;
create policy purchases_owner_delete on public.purchase_requests
  for delete to authenticated
  using (public.current_app_role() = 'owner');

drop policy if exists notifications_staff_select on public.notifications;
create policy notifications_staff_select on public.notifications
  for select to authenticated
  using (
    public.is_active_staff() and (
      audience = 'all_staff'
      or (audience = 'managers' and public.is_manager())
      or (audience = 'owners' and public.current_app_role() = 'owner')
    )
  );

drop policy if exists notifications_manager_insert on public.notifications;
create policy notifications_manager_insert on public.notifications
  for insert to authenticated
  with check (public.is_manager() and created_by = auth.uid());

drop policy if exists device_tokens_own_select on public.device_tokens;
create policy device_tokens_own_select on public.device_tokens
  for select to authenticated using (user_id = auth.uid());

drop policy if exists device_tokens_own_insert on public.device_tokens;
create policy device_tokens_own_insert on public.device_tokens
  for insert to authenticated with check (
    user_id = auth.uid() and public.is_active_staff()
  );

drop policy if exists device_tokens_own_update on public.device_tokens;
create policy device_tokens_own_update on public.device_tokens
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists device_tokens_own_delete on public.device_tokens;
create policy device_tokens_own_delete on public.device_tokens
  for delete to authenticated using (user_id = auth.uid());

drop policy if exists deliveries_own_select on public.notification_deliveries;
create policy deliveries_own_select on public.notification_deliveries
  for select to authenticated using (user_id = auth.uid());

drop policy if exists deliveries_own_read_update on public.notification_deliveries;
create policy deliveries_own_read_update on public.notification_deliveries
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists audit_manager_select on public.audit_log;
create policy audit_manager_select on public.audit_log
  for select to authenticated using (public.is_manager());

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.site_state from anon, authenticated;
revoke all on table public.customers from anon, authenticated;
revoke all on table public.payments from anon, authenticated;
revoke all on table public.purchase_requests from anon, authenticated;
revoke all on table public.notifications from anon, authenticated;
revoke all on table public.device_tokens from anon, authenticated;
revoke all on table public.notification_deliveries from anon, authenticated;
revoke all on table public.audit_log from anon, authenticated;

grant select on table public.site_state to anon, authenticated;
grant select on table public.profiles to authenticated;
grant update (display_name, avatar_url) on table public.profiles to authenticated;
grant update on table public.site_state to authenticated;
grant select, insert, update, delete on table public.customers to authenticated;
grant select, insert, update, delete on table public.payments to authenticated;
grant select, insert, update, delete on table public.purchase_requests to authenticated;
grant select, insert on table public.notifications to authenticated;
grant select, insert, update, delete on table public.device_tokens to authenticated;
grant select, update on table public.notification_deliveries to authenticated;
grant select on table public.audit_log to authenticated;

revoke all on function public.current_app_role() from public;
revoke all on function public.is_active_staff() from public;
revoke all on function public.is_manager() from public;
revoke all on function public.set_staff_access(uuid, public.app_role, boolean) from public;
grant execute on function public.current_app_role() to authenticated;
grant execute on function public.is_active_staff() to authenticated;
grant execute on function public.is_manager() to authenticated;
grant execute on function public.set_staff_access(uuid, public.app_role, boolean) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'site_state'
    ) then
      alter publication supabase_realtime add table public.site_state;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'notifications'
    ) then
      alter publication supabase_realtime add table public.notifications;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'purchase_requests'
    ) then
      alter publication supabase_realtime add table public.purchase_requests;
    end if;
  end if;
end $$;
