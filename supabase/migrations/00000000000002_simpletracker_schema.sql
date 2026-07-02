-- SimpleTracker schema migration
-- Creates tables for notes, tasks, projects, and their related entities

-- =============================================================================
-- Tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.task_projects (
  "recordID" character varying NOT NULL PRIMARY KEY,
  "creatorID" uuid NOT NULL,
  "name" character varying NOT NULL,
  "description" text NOT NULL DEFAULT '',
  "createdAt" bigint NOT NULL,
  "updatedAt" bigint NOT NULL
);

CREATE TABLE IF NOT EXISTS public.task_projects_shared (
  "recordID" character varying NOT NULL PRIMARY KEY,
  "projectID" character varying NOT NULL,
  "sharedToID" uuid NOT NULL,
  "createdAt" bigint NOT NULL,
  "creatorID" uuid NOT NULL
);

CREATE TABLE IF NOT EXISTS public.notes (
  "recordID" character varying NOT NULL PRIMARY KEY,
  "creatorID" uuid NOT NULL,
  "title" character varying NOT NULL DEFAULT '',
  "body" text NOT NULL DEFAULT '',
  "createdAt" bigint NOT NULL,
  "updatedAt" bigint NOT NULL,
  "archived" boolean NOT NULL DEFAULT false,
  "projectID" character varying,
  "pinned" boolean NOT NULL DEFAULT false,
  "noteType" character varying DEFAULT 'text'
);

CREATE TABLE IF NOT EXISTS public.notes_listitems (
  "recordID" character varying NOT NULL PRIMARY KEY,
  "noteID" character varying NOT NULL,
  "title" character varying NOT NULL DEFAULT '',
  "isCompleted" boolean NOT NULL DEFAULT false,
  "createdAt" bigint NOT NULL,
  "updatedAt" bigint NOT NULL,
  "indexOrder" integer
);

CREATE TABLE IF NOT EXISTS public.notes_shared (
  "recordID" character varying NOT NULL PRIMARY KEY,
  "noteID" character varying NOT NULL,
  "sharedToID" uuid NOT NULL,
  "creatorID" uuid NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tasks (
  "recordID" character varying NOT NULL PRIMARY KEY,
  "creatorID" uuid NOT NULL,
  "projectID" character varying,
  "title" character varying NOT NULL,
  "body" text NOT NULL DEFAULT '',
  "status" character varying NOT NULL DEFAULT 'open',
  "dueDate" bigint,
  "isRecurring" boolean NOT NULL DEFAULT false,
  "recurrenceInterval" integer,
  "recurrenceUnit" character varying,
  "recurrenceAnchor" character varying NOT NULL DEFAULT 'due_date',
  "completedAt" bigint,
  "createdAt" bigint NOT NULL,
  "updatedAt" bigint NOT NULL
);

CREATE TABLE IF NOT EXISTS public.task_subtasks (
  "recordID" character varying NOT NULL PRIMARY KEY,
  "taskID" character varying NOT NULL,
  "title" character varying NOT NULL,
  "isCompleted" boolean NOT NULL DEFAULT false,
  "createdAt" bigint NOT NULL,
  "updatedAt" bigint NOT NULL
);

-- =============================================================================
-- Foreign Keys (idempotent - skips if constraint already exists)
-- =============================================================================

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'task_projects_creatorID_fkey') THEN
    ALTER TABLE public.task_projects
      ADD CONSTRAINT "task_projects_creatorID_fkey"
      FOREIGN KEY ("creatorID") REFERENCES public.users("recordID");
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'task_projects_shared_projectID_fkey') THEN
    ALTER TABLE public.task_projects_shared
      ADD CONSTRAINT "task_projects_shared_projectID_fkey"
      FOREIGN KEY ("projectID") REFERENCES public.task_projects("recordID");
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'task_projects_shared_creatorID_fkey') THEN
    ALTER TABLE public.task_projects_shared
      ADD CONSTRAINT "task_projects_shared_creatorID_fkey"
      FOREIGN KEY ("creatorID") REFERENCES public.users("recordID");
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'task_projects_shared_sharedToID_fkey') THEN
    ALTER TABLE public.task_projects_shared
      ADD CONSTRAINT "task_projects_shared_sharedToID_fkey"
      FOREIGN KEY ("sharedToID") REFERENCES public.users("recordID");
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'notes_creatorID_fkey') THEN
    ALTER TABLE public.notes
      ADD CONSTRAINT "notes_creatorID_fkey"
      FOREIGN KEY ("creatorID") REFERENCES public.users("recordID");
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'notes_projectID_fkey') THEN
    ALTER TABLE public.notes
      ADD CONSTRAINT "notes_projectID_fkey"
      FOREIGN KEY ("projectID") REFERENCES public.task_projects("recordID");
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'notes_listitems_noteID_fkey') THEN
    ALTER TABLE public.notes_listitems
      ADD CONSTRAINT "notes_listitems_noteID_fkey"
      FOREIGN KEY ("noteID") REFERENCES public.notes("recordID");
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'notes_shared_noteID_fkey') THEN
    ALTER TABLE public.notes_shared
      ADD CONSTRAINT "notes_shared_noteID_fkey"
      FOREIGN KEY ("noteID") REFERENCES public.notes("recordID");
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'notes_shared_creatorID_fkey') THEN
    ALTER TABLE public.notes_shared
      ADD CONSTRAINT "notes_shared_creatorID_fkey"
      FOREIGN KEY ("creatorID") REFERENCES public.users("recordID");
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'notes_shared_sharedToID_fkey') THEN
    ALTER TABLE public.notes_shared
      ADD CONSTRAINT "notes_shared_sharedToID_fkey"
      FOREIGN KEY ("sharedToID") REFERENCES public.users("recordID");
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tasks_creatorID_fkey') THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT "tasks_creatorID_fkey"
      FOREIGN KEY ("creatorID") REFERENCES public.users("recordID");
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tasks_projectID_fkey') THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT "tasks_projectID_fkey"
      FOREIGN KEY ("projectID") REFERENCES public.task_projects("recordID");
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'task_subtasks_taskID_fkey') THEN
    ALTER TABLE public.task_subtasks
      ADD CONSTRAINT "task_subtasks_taskID_fkey"
      FOREIGN KEY ("taskID") REFERENCES public.tasks("recordID");
  END IF;
END $$;

-- =============================================================================
-- Enable Row Level Security
-- =============================================================================

ALTER TABLE public.task_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_projects_shared ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes_listitems ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes_shared ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_subtasks ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- RLS Policies: task_projects
-- =============================================================================

DROP POLICY IF EXISTS "task_projects_select" ON public.task_projects;
CREATE POLICY "task_projects_select"
  ON public.task_projects FOR SELECT
  TO authenticated
  USING (
    ("creatorID" = auth.uid())
    OR
    (EXISTS (
      SELECT 1 FROM task_projects_shared ps
      WHERE (ps."projectID")::text = (task_projects."recordID")::text
        AND ps."sharedToID" = auth.uid()
    ))
  );

DROP POLICY IF EXISTS "task_projects_insert" ON public.task_projects;
CREATE POLICY "task_projects_insert"
  ON public.task_projects FOR INSERT
  TO authenticated
  WITH CHECK ("creatorID" = auth.uid());

DROP POLICY IF EXISTS "task_projects_update" ON public.task_projects;
CREATE POLICY "task_projects_update"
  ON public.task_projects FOR UPDATE
  TO authenticated
  USING ("creatorID" = auth.uid())
  WITH CHECK ("creatorID" = auth.uid());

DROP POLICY IF EXISTS "task_projects_delete" ON public.task_projects;
CREATE POLICY "task_projects_delete"
  ON public.task_projects FOR DELETE
  TO authenticated
  USING ("creatorID" = auth.uid());

-- =============================================================================
-- RLS Policies: task_projects_shared
-- =============================================================================

DROP POLICY IF EXISTS "task_projects_shared_select" ON public.task_projects_shared;
CREATE POLICY "task_projects_shared_select"
  ON public.task_projects_shared FOR SELECT
  TO authenticated
  USING (
    ("creatorID" = auth.uid())
    OR
    ("sharedToID" = auth.uid())
  );

DROP POLICY IF EXISTS "task_projects_shared_insert" ON public.task_projects_shared;
CREATE POLICY "task_projects_shared_insert"
  ON public.task_projects_shared FOR INSERT
  TO authenticated
  WITH CHECK ("creatorID" = auth.uid());

DROP POLICY IF EXISTS "task_projects_shared_update" ON public.task_projects_shared;
CREATE POLICY "task_projects_shared_update"
  ON public.task_projects_shared FOR UPDATE
  TO authenticated
  USING ("creatorID" = auth.uid())
  WITH CHECK ("creatorID" = auth.uid());

DROP POLICY IF EXISTS "task_projects_shared_delete" ON public.task_projects_shared;
CREATE POLICY "task_projects_shared_delete"
  ON public.task_projects_shared FOR DELETE
  TO authenticated
  USING ("creatorID" = auth.uid());

-- =============================================================================
-- RLS Policies: notes
-- =============================================================================

DROP POLICY IF EXISTS "notes_select" ON public.notes;
CREATE POLICY "notes_select"
  ON public.notes FOR SELECT
  TO authenticated
  USING (
    ("creatorID" = auth.uid())
    OR
    (EXISTS (
      SELECT 1 FROM notes_shared ns
      WHERE (ns."noteID")::text = (notes."recordID")::text
        AND ns."sharedToID" = auth.uid()
    ))
    OR
    (EXISTS (
      SELECT 1 FROM task_projects_shared ps
      WHERE (ps."projectID")::text = (notes."projectID")::text
        AND ps."sharedToID" = auth.uid()
    ))
    OR
    (EXISTS (
      SELECT 1 FROM task_projects p
      WHERE (p."recordID")::text = (notes."projectID")::text
        AND p."creatorID" = auth.uid()
    ))
  );

DROP POLICY IF EXISTS "notes_insert" ON public.notes;
CREATE POLICY "notes_insert"
  ON public.notes FOR INSERT
  TO authenticated
  WITH CHECK (
    ("creatorID" = auth.uid())
    AND (
      ("projectID" IS NULL)
      OR
      (EXISTS (
        SELECT 1 FROM task_projects p
        WHERE (p."recordID")::text = (notes."projectID")::text
          AND p."creatorID" = auth.uid()
      ))
      OR
      (EXISTS (
        SELECT 1 FROM task_projects_shared ps
        WHERE (ps."projectID")::text = (notes."projectID")::text
          AND ps."sharedToID" = auth.uid()
      ))
    )
  );

DROP POLICY IF EXISTS "notes_update" ON public.notes;
CREATE POLICY "notes_update"
  ON public.notes FOR UPDATE
  TO authenticated
  USING (
    ("creatorID" = auth.uid())
    OR
    (EXISTS (
      SELECT 1 FROM notes_shared ns
      WHERE (ns."noteID")::text = (notes."recordID")::text
        AND ns."sharedToID" = auth.uid()
    ))
    OR
    (EXISTS (
      SELECT 1 FROM task_projects_shared ps
      WHERE (ps."projectID")::text = (notes."projectID")::text
        AND ps."sharedToID" = auth.uid()
    ))
  )
  WITH CHECK (
    ("creatorID" = auth.uid())
    OR
    (EXISTS (
      SELECT 1 FROM notes_shared ns
      WHERE (ns."noteID")::text = (notes."recordID")::text
        AND ns."sharedToID" = auth.uid()
    ))
    OR
    (EXISTS (
      SELECT 1 FROM task_projects_shared ps
      WHERE (ps."projectID")::text = (notes."projectID")::text
        AND ps."sharedToID" = auth.uid()
    ))
  );

DROP POLICY IF EXISTS "notes_delete" ON public.notes;
CREATE POLICY "notes_delete"
  ON public.notes FOR DELETE
  TO authenticated
  USING ("creatorID" = auth.uid());

-- =============================================================================
-- RLS Policies: notes_listitems
-- =============================================================================

DROP POLICY IF EXISTS "notes_listitems_select" ON public.notes_listitems;
CREATE POLICY "notes_listitems_select"
  ON public.notes_listitems FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM notes n
      WHERE (n."recordID")::text = (notes_listitems."noteID")::text
        AND (
          (n."creatorID" = auth.uid())
          OR
          (EXISTS (
            SELECT 1 FROM notes_shared ns
            WHERE (ns."noteID")::text = (n."recordID")::text
              AND ns."sharedToID" = auth.uid()
          ))
          OR
          (EXISTS (
            SELECT 1 FROM task_projects_shared ps
            WHERE (ps."projectID")::text = (n."projectID")::text
              AND ps."sharedToID" = auth.uid()
          ))
        )
    )
  );

DROP POLICY IF EXISTS "notes_listitems_insert" ON public.notes_listitems;
CREATE POLICY "notes_listitems_insert"
  ON public.notes_listitems FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM notes n
      WHERE (n."recordID")::text = (notes_listitems."noteID")::text
        AND (
          (n."creatorID" = auth.uid())
          OR
          (EXISTS (
            SELECT 1 FROM notes_shared ns
            WHERE (ns."noteID")::text = (n."recordID")::text
              AND ns."sharedToID" = auth.uid()
          ))
          OR
          (EXISTS (
            SELECT 1 FROM task_projects_shared ps
            WHERE (ps."projectID")::text = (n."projectID")::text
              AND ps."sharedToID" = auth.uid()
          ))
        )
    )
  );

DROP POLICY IF EXISTS "notes_listitems_update" ON public.notes_listitems;
CREATE POLICY "notes_listitems_update"
  ON public.notes_listitems FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM notes n
      WHERE (n."recordID")::text = (notes_listitems."noteID")::text
        AND (
          (n."creatorID" = auth.uid())
          OR
          (EXISTS (
            SELECT 1 FROM notes_shared ns
            WHERE (ns."noteID")::text = (n."recordID")::text
              AND ns."sharedToID" = auth.uid()
          ))
          OR
          (EXISTS (
            SELECT 1 FROM task_projects_shared ps
            WHERE (ps."projectID")::text = (n."projectID")::text
              AND ps."sharedToID" = auth.uid()
          ))
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM notes n
      WHERE (n."recordID")::text = (notes_listitems."noteID")::text
        AND (
          (n."creatorID" = auth.uid())
          OR
          (EXISTS (
            SELECT 1 FROM notes_shared ns
            WHERE (ns."noteID")::text = (n."recordID")::text
              AND ns."sharedToID" = auth.uid()
          ))
          OR
          (EXISTS (
            SELECT 1 FROM task_projects_shared ps
            WHERE (ps."projectID")::text = (n."projectID")::text
              AND ps."sharedToID" = auth.uid()
          ))
        )
    )
  );

DROP POLICY IF EXISTS "notes_listitems_delete" ON public.notes_listitems;
CREATE POLICY "notes_listitems_delete"
  ON public.notes_listitems FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM notes n
      WHERE (n."recordID")::text = (notes_listitems."noteID")::text
        AND (
          (n."creatorID" = auth.uid())
          OR
          (EXISTS (
            SELECT 1 FROM notes_shared ns
            WHERE (ns."noteID")::text = (n."recordID")::text
              AND ns."sharedToID" = auth.uid()
          ))
          OR
          (EXISTS (
            SELECT 1 FROM task_projects_shared ps
            WHERE (ps."projectID")::text = (n."projectID")::text
              AND ps."sharedToID" = auth.uid()
          ))
        )
    )
  );

-- =============================================================================
-- RLS Policies: notes_shared
-- =============================================================================

DROP POLICY IF EXISTS "notes_shared_select" ON public.notes_shared;
CREATE POLICY "notes_shared_select"
  ON public.notes_shared FOR SELECT
  TO authenticated
  USING (
    ("creatorID" = auth.uid())
    OR
    ("sharedToID" = auth.uid())
  );

DROP POLICY IF EXISTS "notes_shared_insert" ON public.notes_shared;
CREATE POLICY "notes_shared_insert"
  ON public.notes_shared FOR INSERT
  TO authenticated
  WITH CHECK ("creatorID" = auth.uid());

DROP POLICY IF EXISTS "notes_shared_update" ON public.notes_shared;
CREATE POLICY "notes_shared_update"
  ON public.notes_shared FOR UPDATE
  TO authenticated
  USING ("creatorID" = auth.uid())
  WITH CHECK ("creatorID" = auth.uid());

DROP POLICY IF EXISTS "notes_shared_delete" ON public.notes_shared;
CREATE POLICY "notes_shared_delete"
  ON public.notes_shared FOR DELETE
  TO authenticated
  USING ("creatorID" = auth.uid());

-- =============================================================================
-- RLS Policies: tasks
-- =============================================================================

DROP POLICY IF EXISTS "tasks_select" ON public.tasks;
CREATE POLICY "tasks_select"
  ON public.tasks FOR SELECT
  TO authenticated
  USING (
    ("creatorID" = auth.uid())
    OR
    (EXISTS (
      SELECT 1 FROM task_projects p
      WHERE (p."recordID")::text = (tasks."projectID")::text
        AND p."creatorID" = auth.uid()
    ))
    OR
    (EXISTS (
      SELECT 1 FROM task_projects_shared ps
      WHERE (ps."projectID")::text = (tasks."projectID")::text
        AND ps."sharedToID" = auth.uid()
    ))
  );

DROP POLICY IF EXISTS "tasks_insert" ON public.tasks;
CREATE POLICY "tasks_insert"
  ON public.tasks FOR INSERT
  TO authenticated
  WITH CHECK (
    ("creatorID" = auth.uid())
    AND (
      ("projectID" IS NULL)
      OR
      (EXISTS (
        SELECT 1 FROM task_projects p
        WHERE (p."recordID")::text = (tasks."projectID")::text
          AND p."creatorID" = auth.uid()
      ))
      OR
      (EXISTS (
        SELECT 1 FROM task_projects_shared ps
        WHERE (ps."projectID")::text = (tasks."projectID")::text
          AND ps."sharedToID" = auth.uid()
      ))
    )
  );

DROP POLICY IF EXISTS "tasks_update" ON public.tasks;
CREATE POLICY "tasks_update"
  ON public.tasks FOR UPDATE
  TO authenticated
  USING (
    ("creatorID" = auth.uid())
    OR
    (EXISTS (
      SELECT 1 FROM task_projects_shared ps
      WHERE (ps."projectID")::text = (tasks."projectID")::text
        AND ps."sharedToID" = auth.uid()
    ))
  )
  WITH CHECK (
    ("creatorID" = auth.uid())
    OR
    (EXISTS (
      SELECT 1 FROM task_projects_shared ps
      WHERE (ps."projectID")::text = (tasks."projectID")::text
        AND ps."sharedToID" = auth.uid()
    ))
  );

DROP POLICY IF EXISTS "tasks_delete" ON public.tasks;
CREATE POLICY "tasks_delete"
  ON public.tasks FOR DELETE
  TO authenticated
  USING ("creatorID" = auth.uid());

-- =============================================================================
-- RLS Policies: task_subtasks
-- =============================================================================

DROP POLICY IF EXISTS "task_subtasks_select" ON public.task_subtasks;
CREATE POLICY "task_subtasks_select"
  ON public.task_subtasks FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM tasks t
      WHERE (t."recordID")::text = (task_subtasks."taskID")::text
        AND (
          (t."creatorID" = auth.uid())
          OR
          (EXISTS (
            SELECT 1 FROM task_projects_shared ps
            WHERE (ps."projectID")::text = (t."projectID")::text
              AND ps."sharedToID" = auth.uid()
          ))
        )
    )
  );

DROP POLICY IF EXISTS "task_subtasks_insert" ON public.task_subtasks;
CREATE POLICY "task_subtasks_insert"
  ON public.task_subtasks FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM tasks t
      WHERE (t."recordID")::text = (task_subtasks."taskID")::text
        AND (
          (t."creatorID" = auth.uid())
          OR
          (EXISTS (
            SELECT 1 FROM task_projects_shared ps
            WHERE (ps."projectID")::text = (t."projectID")::text
              AND ps."sharedToID" = auth.uid()
          ))
        )
    )
  );

DROP POLICY IF EXISTS "task_subtasks_update" ON public.task_subtasks;
CREATE POLICY "task_subtasks_update"
  ON public.task_subtasks FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM tasks t
      WHERE (t."recordID")::text = (task_subtasks."taskID")::text
        AND (
          (t."creatorID" = auth.uid())
          OR
          (EXISTS (
            SELECT 1 FROM task_projects_shared ps
            WHERE (ps."projectID")::text = (t."projectID")::text
              AND ps."sharedToID" = auth.uid()
          ))
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM tasks t
      WHERE (t."recordID")::text = (task_subtasks."taskID")::text
        AND (
          (t."creatorID" = auth.uid())
          OR
          (EXISTS (
            SELECT 1 FROM task_projects_shared ps
            WHERE (ps."projectID")::text = (t."projectID")::text
              AND ps."sharedToID" = auth.uid()
          ))
        )
    )
  );

DROP POLICY IF EXISTS "task_subtasks_delete" ON public.task_subtasks;
CREATE POLICY "task_subtasks_delete"
  ON public.task_subtasks FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM tasks t
      WHERE (t."recordID")::text = (task_subtasks."taskID")::text
        AND t."creatorID" = auth.uid()
    )
  );

-- =============================================================================
-- Grant permissions to roles
-- =============================================================================

GRANT ALL ON public.task_projects TO anon, authenticated, service_role;
GRANT ALL ON public.task_projects_shared TO anon, authenticated, service_role;
GRANT ALL ON public.notes TO anon, authenticated, service_role;
GRANT ALL ON public.notes_listitems TO anon, authenticated, service_role;
GRANT ALL ON public.notes_shared TO anon, authenticated, service_role;
GRANT ALL ON public.tasks TO anon, authenticated, service_role;
GRANT ALL ON public.task_subtasks TO anon, authenticated, service_role;
