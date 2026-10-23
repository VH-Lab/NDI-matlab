function out = calculationDocuments(sessions, entityIds, recordings, sharedIds, cfg, throwErrors)
%CALCULATIONDOCUMENTS Stage 6 (template): what was computed from the data.
%
%   OUT = calculationDocuments(SESSIONS, ENTITYIDS, RECORDINGS, SHAREDIDS, CFG,
%   THROWERRORS) builds, for each row of a session's source table with a
%   value in CFG.calculations.value_column, a calculation whose value kind
%   is CFG.calculations.data_type (length in the template: a diameter in
%   mm, stored in metres with the source's mm kept) about the row's entity. A
%   calculation lists the statements it was computed from: its input is the
%   row's recording (stage 3's statement, 'InputIds'), and it is timed by
%   that recording. Variable and method by NAME from the term registry.
%
%   The method is ONE block, `interaction.method: {term, parameters}`
%   (did-schema #88): 'Method' is its term and 'MethodParameters' its
%   settings (did2.build.parameter / list). A named method shared by many
%   statements is instead a standalone `method` document
%   (did2.build.method) the statements point at by 'MethodId' -- never both.
%
%   Its run environment: 'SoftwareId' (CFG.calculations.software), the
%   REQUIRED 'OperatingSystemId' (operating_system) and, when given,
%   'InterpreterId' (interpreter) -- spec keys of dataset-level software
%   entities (stage 1; SHAREDIDS maps spec key -> id).
%
%   TEMPLATE: a real importer names its own analysis software, and stores a
%   value too large to inline in a data body.
%
%   OUT fields: documents (cell per session), report.

arguments
    sessions table
    entityIds table
    recordings table
    sharedIds
    cfg (1,1) struct
    throwErrors (1,1) logical
end
r = newReport('calculations');
c = cfg.calculations;
n = height(sessions);
docs = repmat({{}}, n, 1);
variable = termByName(c.variable);
method = termByName(c.method);
env = {};
for e = {'software', 'SoftwareId'; 'operating_system', 'OperatingSystemId'; ...
        'interpreter', 'InterpreterId'}'
    key = '';
    if isfield(c, e{1}), key = char(c.(e{1})); end
    if isempty(key), continue; end
    if ~isKey(sharedIds, key)
        error('ndi:setup:conv:template:noSoftware', ['calculations.%s names "%s", which ' ...
            'is not a key in the spec''s `software`.'], e{1}, key);
    end
    env = [env, {e{2}, sharedIds(key)}]; %#ok<AGROW>
end
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
        where = sprintf('%s row %d (%s)', ref, k, rowId);
        try
            text = cellText(T, k, c.value_column);
            [text, note, r] = correctedText(cfg, r, ref, rowId, c.value_column, text);
            if isempty(text)
                r = skipRow(r, where, sprintf('no %s', c.value_column));
                continue;
            end
            subject = subjectOf(entityIds, ref, rowId);
            rec = find(strcmp(recordings.session, ref) & strcmp(recordings.row, rowId), 1);
            if isempty(subject) || isempty(rec)
                r = skipRow(r, where, 'no entity or no recording it was computed from');
                continue;
            end
            st = did2.build.statement('calculation', subject, variable, quantityCell(c, text), ...
                'Method', method, 'InputIds', recordings.statement_id(rec), ...
                'TimeReferenceIds', recordings.time_reference_id(rec), ...
                'Notes', note, 'SessionId', sid, env{:}, 'ValueKind', char(c.data_type));
            docs{s}{end+1} = st;
            r.written = r.written + 1;
            r.documents = r.documents + 1;
        catch err
            r = rowError(r, where, err, throwErrors);
        end
    end
end
out = struct('documents', {docs}, 'report', r);
end
