-- We only look at host metric extensions
SELECT 'EXTENSION='||name||'|'||MAX(version)
FROM   sysman.em_mext_versions_e
WHERE  target_type = 'host'
GROUP  BY name;