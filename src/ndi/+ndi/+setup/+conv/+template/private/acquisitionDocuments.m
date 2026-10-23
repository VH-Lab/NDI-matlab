function out = acquisitionDocuments(sessions, entityIds, cfg, throwErrors, options)
%ACQUISITIONDOCUMENTS Stage 3 (template): the recordings, by location.
%
%   OUT = acquisitionDocuments(SESSIONS, ENTITYIDS, CFG, THROWERRORS) builds,
%   for each row of a session's source table that names a recording file
%   (CFG.acquisition.file_column) in the session's data folder, these five
%   documents, in one call to ndi.setup.V2.recordingDocuments:
%
%     absolute_time_reference  the recording's UTC extent, from the row's
%                              start (start_column, read in time_zone, exact)
%                              and duration (duration_column, seconds)
%     entity (type epoch)      the recording's epoch, its local_identifier
%                              <session>_<file stem>
%     relative_time_reference  the epoch's own clock, dev_local_time from 0
%     observation              the recording: an observation with the value
%                              kind CFG.acquisition.value_kind of the row's
%                              entity, variable and
%                              method looked up by NAME in the term registry,
%                              its value in a data body
%     opaque_body              the raw file, recorded BY LOCATION (ingest 0,
%                              the absolute path), never copied: the format a
%                              registered term, size and (with 'Checksums')
%                              the MD5
%
%   Every statement needs a time reference, so this stage comes before any
%   manipulation, observation or calculation, and each later statement about
%   a recording is timed by the recording's reference.
%
%   TEMPLATE: a real importer adds what NDI's acquisition objects are rebuilt
%   from -- an acquisition_system per device with its acquisition_reader,
%   epoch_file_pattern and acquisition_channels (the Haley import's
%   sessionDocuments.m) -- the instrument (a dataset-level device entity,
%   'InstrumentId'), and the recording's keys (its dimensions).
%
%   Options: 'Checksums' (default true).
%
%   OUT fields: documents (cell per session), recordings (table: session,
%   row, epoch, statement_id, time_reference_id, file), report.

arguments
    sessions table
    entityIds table
    cfg (1,1) struct
    throwErrors (1,1) logical
    options.Checksums (1,1) logical = true
end
r = newReport('acquisition');
a = cfg.acquisition;
n = height(sessions);
docs = repmat({{}}, n, 1);
recs = cell(0, 6);
variable = termByName(a.variable);
method = termByName(a.method);
fileFormat = termByName(a.format);
for s = 1:n
    ref = sessions.local_identifier{s};
    sid = sessions.session_id{s};
    folder = sessions.folder{s};
    if ~startsWith(folder, filesep) && isempty(regexp(folder, '^[A-Za-z]:', 'once'))
        folder = fullfile(pwd, folder);   % a body records an ABSOLUTE location
    end
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
            file = cellText(T, k, a.file_column);
            if isempty(file)
                r = skipRow(r, where, sprintf('no recording (%s is blank)', a.file_column));
                continue;
            end
            src = fullfile(folder, file);
            if ~isfile(src)
                r = skipRow(r, where, sprintf('%s is named but not on disk', file));
                continue;
            end
            subject = subjectOf(entityIds, ref, rowId);
            if isempty(subject)
                r = skipRow(r, where, 'its entity was not made (entities stage)');
                continue;
            end
            startText = cellText(T, k, a.start_column);
            if isempty(startText)
                r = skipRow(r, where, sprintf('no start (%s is blank): no time, no recording', ...
                    a.start_column));
                continue;
            end
            t0 = datetime(startText, 'InputFormat', a.start_format);
            dur = str2double(cellText(T, k, a.duration_column));
            if isnan(dur)
                dur = [];
            end

            % the five documents one recorded file needs, joined, in one call
            [~, stem] = fileparts(file);
            [built, ids] = ndi.setup.V2.recordingDocuments(subject, src, t0, a.time_zone, sid, ...
                'ValueKind', a.value_kind, 'Variable', variable, 'Method', method, 'Format', fileFormat, ...
                'DatumType', a.datum_type, 'Duration', dur, 'SourceText', startText, ...
                'Epoch', sprintf('%s_%s', ref, stem), 'Checksums', options.Checksums);
            docs{s} = [docs{s}, built];
            recs(end+1, :) = {ref, rowId, ids.epoch_id, ids.statement_id, ...
                ids.time_reference_id, src}; %#ok<AGROW>
            r.written = r.written + 1;
            r.documents = r.documents + numel(built);
        catch err
            r = rowError(r, where, err, throwErrors);
        end
    end
end
out = struct('documents', {docs}, 'recordings', cell2table(recs, 'VariableNames', ...
    {'session', 'row', 'epoch', 'statement_id', 'time_reference_id', 'file'}), 'report', r);
end
