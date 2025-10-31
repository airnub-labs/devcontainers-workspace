# Example: Running Migrations

This example demonstrates various workflows for creating, applying, and managing Supabase database migrations in the Airnub Meta Workspace.

> **⚠️ Customization Note:**
> This example uses `$WORKSPACE_ROOT` as the workspace root directory. By default, this is `/airnub-labs`, but you can customize it by setting the `WORKSPACE_ROOT` environment variable. Replace `my-app` with your actual project directory name.

---

## Scenario

You're working on `my-app` and need to add a new feature that requires database changes:
- Add a `posts` table
- Add a foreign key to `users` table
- Create Row Level Security (RLS) policies

---

## Prerequisites

- Project is set up in `$WORKSPACE_ROOT/my-app`
- Supabase is running (`supabase status` shows active)
- You've switched to the project (`airnub use ./my-app`)

---

## Understanding Migrations

**What are migrations?**
- SQL files that define incremental schema changes
- Stored in `supabase/migrations/` directory
- Applied in order based on timestamp prefix
- Tracked in database to prevent duplicate application

**Migration naming:**
```
supabase/migrations/20231030120000_add_posts_table.sql
                    └─timestamp─┘ └─description──┘
```

---

## Workflow 1: Create and Apply a Simple Migration

### Step 1: Create Migration File

```bash
cd $WORKSPACE_ROOT/my-app

# Create new migration
supabase migration new add_posts_table
```

**Expected output:**
```
Created new migration at supabase/migrations/20231030120000_add_posts_table.sql
```

---

### Step 2: Edit Migration File

```bash
# Open in VS Code
code supabase/migrations/20231030120000_add_posts_table.sql
```

**Add SQL content:**
```sql
-- Create posts table
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  title text not null,
  content text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Create index for faster lookups
create index posts_user_id_idx on public.posts(user_id);

-- Enable Row Level Security
alter table public.posts enable row level security;

-- Create policy: users can read all posts
create policy "Posts are viewable by everyone"
  on public.posts
  for select
  using (true);

-- Create policy: users can insert their own posts
create policy "Users can create their own posts"
  on public.posts
  for insert
  with check (auth.uid() = user_id);

-- Create policy: users can update their own posts
create policy "Users can update their own posts"
  on public.posts
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Create policy: users can delete their own posts
create policy "Users can delete their own posts"
  on public.posts
  for delete
  using (auth.uid() = user_id);
```

---

### Step 3: Apply Migration

```bash
# Apply migration to shared database
airnub db apply
```

**Expected output:**
```
Applying migration: 20231030120000_add_posts_table.sql
✓ Migration applied successfully
```

---

### Step 4: Verify Migration

**Option A: Check in Supabase Studio**
```bash
# Open http://localhost:54323
# Navigate to: Table Editor
# You should see the new "posts" table
```

**Option B: Check with psql**
```bash
# Connect to database
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres

# List tables
\dt public.*

# View posts table schema
\d public.posts

# Check policies
\d+ public.posts

# Exit
\q
```

**Option C: Check migration status**
```bash
cd my-app
supabase migration list
```

**Expected output:**
```
    LOCAL      │     REMOTE     │     TIME (UTC)      │         NAME
 ──────────────┼────────────────┼─────────────────────┼──────────────────────────
  20231030120000 │ 20231030120000 │ 2023-10-30 12:00:00 │ add_posts_table
```

---

## Workflow 2: Create Multiple Related Migrations

### Scenario: Add Comments Feature

This requires multiple tables and relationships. Break into logical migrations:

#### Migration 1: Create Comments Table

```bash
cd my-app
supabase migration new add_comments_table
```

**Edit `supabase/migrations/*_add_comments_table.sql`:**
```sql
-- Create comments table
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references public.posts(id) on delete cascade not null,
  user_id uuid references public.users(id) on delete cascade not null,
  content text not null,
  created_at timestamptz default now()
);

-- Create indexes
create index comments_post_id_idx on public.comments(post_id);
create index comments_user_id_idx on public.comments(user_id);

-- Enable RLS
alter table public.comments enable row level security;
```

#### Migration 2: Add Comment Policies

```bash
supabase migration new add_comments_policies
```

**Edit `supabase/migrations/*_add_comments_policies.sql`:**
```sql
-- Comments are viewable by everyone
create policy "Comments are viewable by everyone"
  on public.comments
  for select
  using (true);

-- Users can create comments
create policy "Users can create comments"
  on public.comments
  for insert
  with check (auth.uid() = user_id);

-- Users can update their own comments (within 1 hour)
create policy "Users can update own comments"
  on public.comments
  for update
  using (
    auth.uid() = user_id
    and created_at > now() - interval '1 hour'
  );

-- Users can delete their own comments
create policy "Users can delete own comments"
  on public.comments
  for delete
  using (auth.uid() = user_id);
```

#### Migration 3: Add Comment Count to Posts

```bash
supabase migration new add_comment_count_to_posts
```

**Edit `supabase/migrations/*_add_comment_count_to_posts.sql`:**
```sql
-- Add comment_count column
alter table public.posts
add column comment_count integer default 0;

-- Create function to update count
create or replace function update_post_comment_count()
returns trigger as $$
begin
  if (TG_OP = 'INSERT') then
    update public.posts
    set comment_count = comment_count + 1
    where id = NEW.post_id;
    return NEW;
  elsif (TG_OP = 'DELETE') then
    update public.posts
    set comment_count = comment_count - 1
    where id = OLD.post_id;
    return OLD;
  end if;
  return null;
end;
$$ language plpgsql;

-- Create trigger
create trigger update_post_comment_count_trigger
  after insert or delete on public.comments
  for each row execute function update_post_comment_count();

-- Initialize counts for existing posts
update public.posts p
set comment_count = (
  select count(*)
  from public.comments c
  where c.post_id = p.id
);
```

#### Apply All Migrations

```bash
# Apply all pending migrations at once
airnub db apply
```

---

## Workflow 3: Rollback with Reset

### Scenario: Migration Has Bug, Need to Fix

**Problem:** You applied a migration, but it has a bug (wrong column type, missing index, etc.)

**Solution:** Reset database and reapply with fixed migration

### Step 1: Edit the Buggy Migration

```bash
# Fix the migration file
code supabase/migrations/20231030120000_add_posts_table.sql

# Example: Change column type
# Before: title varchar(100)
# After:  title text
```

---

### Step 2: Reset Database

```bash
# Reset database (destructive!)
airnub db reset
```

**Expected output:**
```
⚠️  WARNING: This will destroy all data in the database!
Continue? (y/N) y

Resetting database...
✓ Database reset
✓ Migrations reapplied

Started supabase local development setup.
         API URL: http://127.0.0.1:54321
...
```

**What happens:**
1. All tables are dropped
2. All data is deleted
3. Migrations are reapplied from scratch (including your fix)

---

### Step 3: Reseed Data (If Needed)

```bash
cd my-app

# Run seed script if you have one
pnpm db:seed

# Or manually add test data
```

---

## Workflow 4: Creating Migrations from Studio

### Scenario: Prototype Schema in Studio UI

Sometimes it's faster to prototype in Supabase Studio's GUI, then generate migration SQL.

### Step 1: Make Changes in Studio

1. Open [http://localhost:54323](http://localhost:54323)
2. Navigate to **SQL Editor**
3. Create your schema changes interactively
4. Test queries

---

### Step 2: Generate Migration SQL

**Option A: Copy from Studio SQL Editor**
```bash
# Create new migration
supabase migration new my_studio_changes

# Paste SQL from Studio into migration file
code supabase/migrations/*_my_studio_changes.sql
```

**Option B: Diff against remote**
```bash
# This compares local migrations vs actual database state
# and generates a migration with the differences
supabase db diff -f my_studio_changes

# Review the generated migration
cat supabase/migrations/*_my_studio_changes.sql
```

---

### Step 3: Apply Migration

```bash
airnub db apply
```

---

## Workflow 5: Squash Migrations (Clean Up)

### Scenario: Too Many Small Migrations

During development, you may create many small migrations. Before merging to main branch, consider squashing them.

### Step 1: Reset Database

```bash
# Save current migrations
cp -r supabase/migrations supabase/migrations.backup

# Reset database
airnub db reset
```

---

### Step 2: Create Single Squashed Migration

```bash
# Create one new migration
supabase migration new initial_schema

# Manually combine all previous migrations into this one
code supabase/migrations/*_initial_schema.sql
```

**Example squashed migration:**
```sql
-- Combined from: add_users, add_posts, add_comments

-- Users table
create table public.users (...);
alter table public.users enable row level security;
create policy ... on public.users ...;

-- Posts table
create table public.posts (...);
alter table public.posts enable row level security;
create policy ... on public.posts ...;

-- Comments table
create table public.comments (...);
alter table public.comments enable row level security;
create policy ... on public.comments ...;
```

---

### Step 3: Delete Old Migrations

```bash
# Remove old individual migrations
rm supabase/migrations/20231030120000_*.sql

# Keep only the squashed one
ls supabase/migrations/
```

---

### Step 4: Test

```bash
# Reset and apply squashed migration
airnub db reset

# Verify schema
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "\dt public.*"
```

---

## Advanced: Data Migrations

### Scenario: Migrate Data, Not Just Schema

Sometimes you need to transform existing data.

**Example migration (`*_migrate_user_roles.sql`):**
```sql
-- Add new column
alter table public.users
add column role text default 'user';

-- Migrate existing data
update public.users
set role = 'admin'
where email like '%@yourcompany.com';

-- Add constraint
alter table public.users
add constraint users_role_check
check (role in ('user', 'admin', 'moderator'));
```

**Best practices:**
- Always add columns with DEFAULT first
- Update data in batches for large tables
- Add constraints AFTER data migration
- Test on development database first

---

## Advanced: Conditional Migrations

### Scenario: Migration Might Fail if Already Applied

**Use IF NOT EXISTS:**
```sql
-- Safe: Won't fail if table already exists
create table if not exists public.posts (...);

-- Safe: Won't fail if column already exists
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'users' and column_name = 'role'
  ) then
    alter table public.users add column role text default 'user';
  end if;
end $$;
```

---

## Troubleshooting

### Error: "relation already exists"

**Symptom:**
```
ERROR: relation "posts" already exists
```

**Cause:** Migration was partially applied or manually created in Studio

**Solution:**
```bash
# Option A: Reset database
airnub db reset

# Option B: Fix migration to use IF NOT EXISTS
# Edit migration file
code supabase/migrations/*_add_posts_table.sql

# Change to:
create table if not exists public.posts (...);
```

---

### Error: "column does not exist"

**Symptom:**
```
ERROR: column "user_id" of relation "posts" does not exist
```

**Cause:** Migrations applied out of order, or dependency missing

**Solution:**
```bash
# Check migration order
supabase migration list

# Ensure migrations have correct timestamps
ls -la supabase/migrations/

# If order is wrong, rename files to fix timestamp order
mv supabase/migrations/20231030_later.sql supabase/migrations/20231031_later.sql

# Reset and reapply
airnub db reset
```

---

### Migration Hangs or Times Out

**Symptom:** `airnub db apply` hangs indefinitely

**Cause:** Migration has expensive operation or deadlock

**Solution:**
```bash
# Cancel the migration (Ctrl+C)

# Check what's running
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres

# See active queries
SELECT * FROM pg_stat_activity WHERE state = 'active';

# Kill long-running query (if needed)
SELECT pg_cancel_backend(pid) FROM pg_stat_activity WHERE state = 'active' AND pid != pg_backend_pid();

\q

# Fix migration to be more efficient
code supabase/migrations/*_slow_migration.sql

# Example: Add indexes CONCURRENTLY
create index concurrently posts_user_id_idx on public.posts(user_id);
```

---

### Data Loss After Reset

**Symptom:** "I ran `airnub db reset` and lost all my data!"

**Prevention:**
- **Never use `reset` in production**
- Always backup data before reset
- Use seed scripts to restore test data

**Recovery:**
```bash
# If you have a seed script
cd my-app
pnpm db:seed

# If you have a SQL dump
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres < backup.sql

# If you have no backup
# Manually recreate data in Supabase Studio or via INSERT statements
```

---

## Best Practices

### 1. Write Idempotent Migrations

```sql
-- ✅ Good: Safe to run multiple times
create table if not exists public.posts (...);
alter table if exists public.users add column if not exists role text;

-- ❌ Bad: Will fail on second run
create table public.posts (...);
alter table public.users add column role text;
```

---

### 2. One Logical Change Per Migration

```bash
# ✅ Good
supabase migration new add_posts_table
supabase migration new add_posts_rls_policies
supabase migration new add_posts_indexes

# ❌ Bad
supabase migration new update_everything
```

---

### 3. Use Descriptive Names

```bash
# ✅ Good
supabase migration new add_users_email_verification_column

# ❌ Bad
supabase migration new update_users
```

---

### 4. Test Migrations Locally First

```bash
# Apply migration
airnub db apply

# Test in app
cd my-app && pnpm dev

# Check Supabase Studio

# If broken, reset and fix
airnub db reset
```

---

### 5. Comment Your SQL

```sql
-- Add email verification for user registration flow
-- Related to ticket: PROJ-123
alter table public.users
add column email_verified boolean default false;

-- Index for fast lookups in auth flow
create index users_email_verified_idx on public.users(email_verified);
```

---

## Related Examples

- [Setting Up a New Project](./setting-up-new-project.md)
- [Switching Between Projects](./switching-projects.md)
- [Debugging with GUI](./debugging-with-gui.md)

## Related Documentation

- [Supabase Operations](../guides/supabase-operations.md)
- [CLI Reference](../reference/cli-reference.md)
- [Troubleshooting](../reference/troubleshooting.md)

---

**Last updated:** 2025-10-31
