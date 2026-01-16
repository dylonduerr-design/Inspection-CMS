class MigrateChecklistQuestionsToObjectSchema < ActiveRecord::Migration[7.1]
  def up
    # Migrate SpecItem checklist_questions from string arrays to object arrays
    execute <<-SQL
      UPDATE spec_items
      SET checklist_questions = (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', lower(regexp_replace(regexp_replace(elem::text, '[^a-zA-Z0-9\\s]', '', 'g'), '\\s+', '_', 'g')) || '_' || ordinality::text,
            'prompt', trim(both '"' from elem::text),
            'kind', 'radio',
            'options', '["Yes", "No", "N/A"]'::jsonb,
            'required', false
          ) ORDER BY ordinality
        )
        FROM jsonb_array_elements(checklist_questions) WITH ORDINALITY AS t(elem, ordinality)
      )
      WHERE checklist_questions IS NOT NULL
        AND jsonb_typeof(checklist_questions) = 'array'
        AND jsonb_array_length(checklist_questions) > 0
        AND jsonb_typeof(checklist_questions->0) = 'string';
    SQL

    # Migrate BidItem checklist_questions from string arrays to object arrays
    execute <<-SQL
      UPDATE bid_items
      SET checklist_questions = (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', lower(regexp_replace(regexp_replace(elem::text, '[^a-zA-Z0-9\\s]', '', 'g'), '\\s+', '_', 'g')) || '_' || ordinality::text,
            'prompt', trim(both '"' from elem::text),
            'kind', 'radio',
            'options', '["Yes", "No", "N/A"]'::jsonb,
            'required', false
          ) ORDER BY ordinality
        )
        FROM jsonb_array_elements(checklist_questions) WITH ORDINALITY AS t(elem, ordinality)
      )
      WHERE checklist_questions IS NOT NULL
        AND jsonb_typeof(checklist_questions) = 'array'
        AND jsonb_array_length(checklist_questions) > 0
        AND jsonb_typeof(checklist_questions->0) = 'string';
    SQL

    # Migrate existing ChecklistEntry answers to use new IDs
    # This maps old prompt-based keys to new ID-based keys
    # Only process rows where checklist_answers is a valid JSON object
    execute <<-SQL
      UPDATE checklist_entries ce
      SET checklist_answers = (
        SELECT jsonb_object_agg(
          COALESCE(
            (
              SELECT q->>'id'
              FROM jsonb_array_elements(si.checklist_questions) AS q
              WHERE q->>'prompt' = kv.key
              LIMIT 1
            ),
            lower(regexp_replace(regexp_replace(kv.key, '[^a-zA-Z0-9\\s]', '', 'g'), '\\s+', '_', 'g'))
          ),
          kv.value
        )
        FROM jsonb_each_text(ce.checklist_answers) AS kv
      )
      FROM spec_items si
      WHERE ce.spec_item_id = si.id
        AND ce.checklist_answers IS NOT NULL
        AND jsonb_typeof(ce.checklist_answers) = 'object'
        AND ce.checklist_answers != '{}'::jsonb;
    SQL

    # Migrate existing PlacedQuantity answers to use new IDs  
    # Only process rows where checklist_answers is a valid JSON object
    execute <<-SQL
      UPDATE placed_quantities pq
      SET checklist_answers = (
        SELECT jsonb_object_agg(
          COALESCE(
            (
              SELECT q->>'id'
              FROM jsonb_array_elements(bi.checklist_questions) AS q
              WHERE q->>'prompt' = kv.key
              LIMIT 1
            ),
            lower(regexp_replace(regexp_replace(kv.key, '[^a-zA-Z0-9\\s]', '', 'g'), '\\s+', '_', 'g'))
          ),
          kv.value
        )
        FROM jsonb_each_text(pq.checklist_answers) AS kv
      )
      FROM bid_items bi
      WHERE pq.bid_item_id = bi.id
        AND pq.checklist_answers IS NOT NULL
        AND jsonb_typeof(pq.checklist_answers) = 'object'
        AND pq.checklist_answers != '{}'::jsonb;
    SQL
  end

  def down
    # Revert SpecItem checklist_questions back to string arrays
    execute <<-SQL
      UPDATE spec_items
      SET checklist_questions = (
        SELECT jsonb_agg(elem->>'prompt' ORDER BY ordinality)
        FROM jsonb_array_elements(checklist_questions) WITH ORDINALITY AS t(elem, ordinality)
      )
      WHERE checklist_questions IS NOT NULL
        AND jsonb_typeof(checklist_questions) = 'array'
        AND jsonb_array_length(checklist_questions) > 0
        AND jsonb_typeof(checklist_questions->0) = 'object';
    SQL

    # Revert BidItem checklist_questions back to string arrays
    execute <<-SQL
      UPDATE bid_items
      SET checklist_questions = (
        SELECT jsonb_agg(elem->>'prompt' ORDER BY ordinality)
        FROM jsonb_array_elements(checklist_questions) WITH ORDINALITY AS t(elem, ordinality)
      )
      WHERE checklist_questions IS NOT NULL
        AND jsonb_typeof(checklist_questions) = 'array'
        AND jsonb_array_length(checklist_questions) > 0
        AND jsonb_typeof(checklist_questions->0) = 'object';
    SQL

    # Revert ChecklistEntry answers back to prompt-based keys
    execute <<-SQL
      UPDATE checklist_entries ce
      SET checklist_answers = (
        SELECT jsonb_object_agg(
          COALESCE(
            (
              SELECT q->>'prompt'
              FROM jsonb_array_elements(si.checklist_questions) AS q
              WHERE q->>'id' = kv.key
              LIMIT 1
            ),
            kv.key
          ),
          kv.value
        )
        FROM jsonb_each_text(ce.checklist_answers) AS kv
      )
      FROM spec_items si
      WHERE ce.spec_item_id = si.id
        AND ce.checklist_answers IS NOT NULL
        AND jsonb_typeof(ce.checklist_answers) = 'object'
        AND ce.checklist_answers != '{}'::jsonb;
    SQL

    # Revert PlacedQuantity answers back to prompt-based keys
    execute <<-SQL
      UPDATE placed_quantities pq
      SET checklist_answers = (
        SELECT jsonb_object_agg(
          COALESCE(
            (
              SELECT q->>'prompt'
              FROM jsonb_array_elements(bi.checklist_questions) AS q
              WHERE q->>'id' = kv.key
              LIMIT 1
            ),
            kv.key
          ),
          kv.value
        )
        FROM jsonb_each_text(pq.checklist_answers) AS kv
      )
      FROM bid_items bi
      WHERE pq.bid_item_id = bi.id
        AND pq.checklist_answers IS NOT NULL
        AND jsonb_typeof(pq.checklist_answers) = 'object'
        AND pq.checklist_answers != '{}'::jsonb;
    SQL
  end
end
