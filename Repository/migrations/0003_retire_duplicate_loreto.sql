-- Retire only the superseded community upload, preserving its author and other prayers.
DELETE FROM bundles WHERE id = 'repo.stgamliel-il.litanyOfMaryTheBlessedEverVirgin';

-- Older deployments must not recreate it before the publishing guard is deployed.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'bundles'::regclass AND conname = 'bundles_retired_loreto'
  ) THEN
    ALTER TABLE bundles ADD CONSTRAINT bundles_retired_loreto
      CHECK (id <> 'repo.stgamliel-il.litanyOfMaryTheBlessedEverVirgin');
  END IF;
END $$;
