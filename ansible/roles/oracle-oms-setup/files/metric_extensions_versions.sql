SELECT 'EXTENSION='||name||'|'||MAX(version)
FROM   sysman.em_mext_versions_e
GROUP  BY name;