function out = observationDocuments(sessions, entityIds, recordings, cfg, throwErrors)
%OBSERVATIONDOCUMENTS Stage 5 (template): what was measured about each entity.
%
%   OUT = observationDocuments(SESSIONS, ENTITYIDS, RECORDINGS, CFG,
%   THROWERRORS) builds, for each row of a session's source table with a
%   value in CFG.observations.value_column, a CFG.observations.leaf statement
%   (temperature_observation in the template) about the row's entity, timed
%   by the row's recording (stage 3's absolute time reference: the reading
%   was taken over the recording). Variable and method by NAME from the term
%   registry; the value through quantityCell, after the spec's corrections.
%   A summary is stated as its quantity with the statistic as its method
%   (tenet T16: a mean temperature is `temperature`, method Arithmetic Mean).
%
%   TEMPLATE: a real importer adds 'InstrumentId' (the dataset-level device
%   that measured it), and times a reading that is not tied to a recording
%   by its own time reference, as the manipulations stage does.
%
%   OUT fields: documents (cell per session), report.

arguments
    sessions table
    entityIds table
    recordings table
    cfg (1,1) struct
    throwErrors (1,1) logical
end
r = newReport('observations');
o = cfg.observations;
n = height(sessions);
docs = repmat({{}}, n, 1);
variable = termByName(o.variable);
method = termByName(o.method);
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
            text = cellText(T, k, o.value_column);
            [text, note, r] = correctedText(cfg, r, ref, rowId, o.value_column, text);
            if isempty(text)
                r = skipRow(r, where, sprintf('no %s', o.value_column));
                continue;
            end
            subject = subjectOf(entityIds, ref, rowId);
            rec = find(strcmp(recordings.session, ref) & strcmp(recordings.row, rowId), 1);
            if isempty(subject) || isempty(rec)
                r = skipRow(r, where, 'no entity or no recording to time it by');
                continue;
            end
            st = did2.build.statement(o.leaf, subject, variable, quantityCell(o, text), ...
                'Method', method, 'TimeReferenceIds', recordings.time_reference_id(rec), ...
                'Notes', note, 'SessionId', sid);
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
