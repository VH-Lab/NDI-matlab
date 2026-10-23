function [T, why] = sessionTable(folder, cfg)
%SESSIONTABLE A session's source table, read once per stage.
%
%   [T, WHY] = sessionTable(FOLDER, CFG) reads FOLDER/<CFG.entities.table>
%   (readSourceTable: every cell as text). T is [] and WHY says why when the
%   folder has no such table.
%
%   TEMPLATE: one table per session folder, one row per subject, is this
%   template's source layout. A real importer reads its own sources here
%   (the Haley import reads experimentInfo / tableOfContents per study).

arguments
    folder {mustBeText}
    cfg (1,1) struct
end
T = [];
why = '';
file = fullfile(folder, cfg.entities.table);
if ~isfile(file)
    why = sprintf('no %s in %s', cfg.entities.table, folder);
    return;
end
T = readSourceTable(file);
if ~ismember(cfg.entities.id_column, T.Properties.VariableNames)
    why = sprintf('%s has no `%s` column (entities.id_column)', file, cfg.entities.id_column);
    T = [];
end
end
