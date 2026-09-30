-- Correct the extra-shot surcharge in the current menu and saved editor data.
-- Existing order snapshots and other menu prices stay unchanged.
UPDATE menu_items
SET options_json = (
  SELECT json_group_array(json(
    CASE
      WHEN json_extract(option.value, '$.id') = 'strength'
        AND json_extract(option.value, '$.type') = 'dots'
        AND json_extract(option.value, '$.pricePerStepVnd') = 20000
      THEN json_set(option.value, '$.pricePerStepVnd', 15000)
      ELSE option.value
    END
  ))
  FROM json_each(menu_items.options_json) AS option
)
WHERE catalog_id IN (SELECT id FROM menu_catalogs WHERE active = 1)
  AND item_key IN ('espresso', 'americano', 'cappuccino', 'latte', 'flat-white')
  AND EXISTS (
    SELECT 1 FROM json_each(menu_items.options_json) AS option
    WHERE json_extract(option.value, '$.id') = 'strength'
      AND json_extract(option.value, '$.type') = 'dots'
      AND json_extract(option.value, '$.pricePerStepVnd') = 20000
  );

-- Patch only matching shot fields; preserve any other saved edits.
WITH RECURSIVE
shot_paths AS (
  SELECT document.id,
    '$.groups[' || menu_group.key || '].items[' || item.key ||
      '].options[' || option.key || '].pricePerStepVnd' AS path,
    row_number() OVER (
      PARTITION BY document.id ORDER BY menu_group.key, item.key, option.key
    ) AS step
  FROM menu_catalogs AS document,
    json_each(document.source_json, '$.groups') AS menu_group,
    json_each(menu_group.value, '$.items') AS item,
    json_each(item.value, '$.options') AS option
  WHERE document.active = 1
    AND json_extract(item.value, '$.id') IN ('espresso', 'americano', 'cappuccino', 'latte', 'flat-white')
    AND json_extract(option.value, '$.id') = 'strength'
    AND json_extract(option.value, '$.type') = 'dots'
    AND json_extract(option.value, '$.pricePerStepVnd') = 20000
),
patched(id, step, source_json) AS (
  SELECT id, 0, source_json FROM menu_catalogs WHERE active = 1
  UNION ALL
  SELECT patched.id, shot_paths.step,
    json_set(patched.source_json, shot_paths.path, 15000)
  FROM patched JOIN shot_paths
    ON shot_paths.id = patched.id AND shot_paths.step = patched.step + 1
)
UPDATE menu_catalogs
SET source_json = (
  SELECT source_json FROM patched WHERE patched.id = menu_catalogs.id
  ORDER BY step DESC LIMIT 1
)
WHERE id IN (SELECT id FROM shot_paths);

-- Patch only matching shot fields; preserve any other saved edits.
WITH RECURSIVE
shot_paths AS (
  SELECT document.id,
    '$.groups[' || menu_group.key || '].items[' || item.key ||
      '].options[' || option.key || '].pricePerStepVnd' AS path,
    row_number() OVER (
      PARTITION BY document.id ORDER BY menu_group.key, item.key, option.key
    ) AS step
  FROM menu_drafts AS document,
    json_each(document.source_json, '$.groups') AS menu_group,
    json_each(menu_group.value, '$.items') AS item,
    json_each(item.value, '$.options') AS option
  WHERE document.id = 1
    AND json_extract(item.value, '$.id') IN ('espresso', 'americano', 'cappuccino', 'latte', 'flat-white')
    AND json_extract(option.value, '$.id') = 'strength'
    AND json_extract(option.value, '$.type') = 'dots'
    AND json_extract(option.value, '$.pricePerStepVnd') = 20000
),
patched(id, step, source_json) AS (
  SELECT id, 0, source_json FROM menu_drafts WHERE id = 1
  UNION ALL
  SELECT patched.id, shot_paths.step,
    json_set(patched.source_json, shot_paths.path, 15000)
  FROM patched JOIN shot_paths
    ON shot_paths.id = patched.id AND shot_paths.step = patched.step + 1
)
UPDATE menu_drafts
SET source_json = (
  SELECT source_json FROM patched WHERE patched.id = menu_drafts.id
  ORDER BY step DESC LIMIT 1
)
WHERE id IN (SELECT id FROM shot_paths);
