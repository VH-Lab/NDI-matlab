function out = manipulationDocuments(sessions, entityIds, cfg, throwErrors)
%MANIPULATIONDOCUMENTS Stage 4 (template): what was done to each entity.
%
%   OUT = manipulationDocuments(SESSIONS, ENTITYIDS, CFG, THROWERRORS) builds,
%   for each row of a session's source table with a value in
%   CFG.manipulations.value_column, a CFG.manipulations.leaf statement
%   (temperature_manipulation in the template) about the row's entity:
%
%     variable / method  looked up by NAME in the term registry
%     value              quantityCell: canonical, source_value, source_unit
%                        (a registered term) -- after the spec's named
%                        corrections (ndi.setup.V2.applyCorrection), whose note the
%                        statement carries
%     when               its own absolute_time_reference at the row's
%                        time_column (ndi.setup.V2.utcReference). A hand-written time is to the minute,
%                        so it is approximate with time_tolerance [60 60] s
%                        and its source_value is the text as written. No time
%                        in the source: no time reference and no manipulation.
%
%   TEMPLATE: a real importer has many manipulations (Haley: pouring and
%   seeding as dose_manipulation, moves between temperatures as
%   temperature_manipulation, transfers and food deprivation as
%   term_manipulation), each a rule recorded in its decision log.
%
%   OUT fields: documents (cell per session), report.

arguments
    sessions table
    entityIds table
    cfg (1,1) struct
    throwErrors (1,1) logical
end
r = newReport('manipulations');
m = cfg.manipulations;
n = height(sessions);
docs = repmat({{}}, n, 1);
variable = termByName(m.variable);
method = termByName(m.method);
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
            text = cellText(T, k, m.value_column);
            [text, note, r] = correctedText(cfg, r, ref, rowId, m.value_column, text);
            if isempty(text)
                r = skipRow(r, where, sprintf('no %s', m.value_column));
                continue;
            end
            whenText = cellText(T, k, m.time_column);
            if isempty(whenText)
                r = skipRow(r, where, sprintf('no %s: no time, no manipulation', m.time_column));
                continue;
            end
            subject = subjectOf(entityIds, ref, rowId);
            if isempty(subject)
                r = skipRow(r, where, 'its entity was not made (entities stage)');
                continue;
            end
            value = quantityCell(m, text);
            t = datetime(whenText, 'InputFormat', m.time_format);
            tol = [];
            if ~isempty(m.time_tolerance), tol = reshape(double(m.time_tolerance), 1, 2); end
            when = ndi.setup.V2.utcReference(t, m.time_zone, sid, 'SourceText', whenText, ...
                'Tolerance', tol);
            st = did2.build.statement(m.leaf, subject, variable, value, 'Method', method, ...
                'TimeReferenceIds', {when.base.id}, 'Notes', note, 'SessionId', sid);
            docs{s} = [docs{s}, {when, st}];
            r.written = r.written + 1;
            r.documents = r.documents + 2;
        catch err
            r = rowError(r, where, err, throwErrors);
        end
    end
end
out = struct('documents', {docs}, 'report', r);
end
