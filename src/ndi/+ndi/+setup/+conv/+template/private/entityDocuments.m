function out = entityDocuments(sessions, cfg, throwErrors)
%ENTITYDOCUMENTS Stage 2 (template): the entities each session is about.
%
%   OUT = entityDocuments(SESSIONS, CFG, THROWERRORS) builds, for each session
%   (stage 1's table), one entity per row of its source table: an `entity` of
%   type CFG.entities.type (organism, culture, tissue, cell, group, device,
%   material: did-schema's entity type registry), local_identifier
%   <session>_<row id> (dataset-unique), name the row id. Built with
%   ndi.setup.V2.entityDocuments, so a field with no home on the entity is an
%   error, never dropped.
%
%   TEMPLATE: a real importer makes every kind of thing the data is about
%   (Haley: plates, patches, worm cohorts, worms), adds the assertions that
%   say what each one is (species, strain, sample type: term assertion), and
%   the relations between them (contained_in, member_of, part_of: 
%   did2.build.directedRelation). Shared entities -- people, strains,
%   instruments, software -- are dataset-level and come from the spec
%   (stage 1).
%
%   OUT fields: documents (cell, one cell of documents per session), ids
%   (table: session, row, local_identifier, id -- what later stages look
%   their subject up in), report.

arguments
    sessions table
    cfg (1,1) struct
    throwErrors (1,1) logical
end
r = newReport('entities');
n = height(sessions);
docs = repmat({{}}, n, 1);
ids = cell(0, 4);
for s = 1:n
    ref = sessions.local_identifier{s};
    sid = sessions.session_id{s};
    [T, why] = sessionTable(sessions.folder{s}, cfg);
    if isempty(T)
        r.read = r.read + 1;
        r = skipRow(r, ref, why);
        continue;
    end
    for k = 1:height(T)
        r.read = r.read + 1;
        rowId = cellText(T, k, cfg.entities.id_column);
        where = sprintf('%s row %d', ref, k);
        try
            if isempty(rowId)
                r = skipRow(r, where, sprintf('no %s', cfg.entities.id_column));
                continue;
            end
            localId = sprintf('%s_%s', ref, rowId);
            d = ndi.setup.V2.entityDocuments('subject', ...
                struct('local_identifier', localId, 'name', rowId), struct(), ...
                'SessionId', sid, 'Type', char(cfg.entities.type));
            docs{s} = [docs{s}, d];
            ids(end+1, :) = {ref, rowId, localId, d{1}.base.id}; %#ok<AGROW>
            r.written = r.written + 1;
            r.documents = r.documents + numel(d);
        catch err
            r = rowError(r, where, err, throwErrors);
        end
    end
end
out = struct('documents', {docs}, ...
    'ids', cell2table(ids, 'VariableNames', {'session', 'row', 'local_identifier', 'id'}), ...
    'report', r);
end
