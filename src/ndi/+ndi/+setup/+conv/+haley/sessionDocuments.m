function out = sessionDocuments(dataParentDir, session, S, R, options)
%SESSIONDOCUMENTS Stages 4-5 (Haley), written: every document for ONE session.
%
%   OUT = ndi.setup.conv.haley.sessionDocuments(DATAPARENTDIR, SESSION, S, R)
%   builds, for the one-row session table SESSION (from sessionList, with
%   `session_id` already assigned), the V2 documents of its subjects (S rows,
%   from subjectList) and recordings (R rows, from recordingList). Nothing is
%   written here (ndi.setup.V2.makeSessions writes the documents), and
%   nothing is ever written into the session folder or the raw data: NDI
%   finds each recording through its documents (ndi.file.navigator.bodies,
%   decision #51). Decision log #28-#35, #45-#51.
%
%   Documents, all with base.session_id = SESSION.session_id:
%     subject                 one per S row (local_identifier, name, description,
%                             and type when the schema has subject.type)
%     absolute_time_reference the session's UTC extent (first recording start
%                             to last recording end); OUT.timeReferenceId, for
%                             session.time_reference_id
%     software                the three NDI classes an acquisition system is
%                             rebuilt from (decision #29): ndi.daq.system.image,
%                             ndi.file.navigator.bodies, ndi.daq.reader.image.ndr
%     acquisition_reader      one per reader string: 'video' (cameras),
%                             'tiffstack' (microscope)
%     epoch_file_pattern      one per system: the file names that are its
%                             recordings (the navigator filters bodies by it)
%     acquisition_system      one per system in the session (camera1, camera2,
%                             microscope; decision #28)
%     acquisition_channels    one per system (no channel numbers: a camera has
%                             no ai/ao/di/do channels, the only types the
%                             schema binds)
%   and per recording (R row):
%     epoch                   local_identifier = R.epoch, which is also NDI's
%                             epoch id (the navigator reads it from here)
%     relative_time_reference dev_local_time from 0 for the recording's
%                             duration, referent the SESSION document (videos)
%     absolute_time_reference its UTC start (and duration when known)
%     intensity_observation   the recording: subject = the plate, instrument =
%                             the dataset-level camera / microscope subject
%                             (when 'InstrumentIds' has it), acquisition
%                             channels = this session's system; times = a
%                             relative reference to the EPOCH (videos: the
%                             same extent; images: `during`) + the UTC one;
%                             method = the imaging method, which is also the
%                             NDI probe type (brightfield-imaging /
%                             wide-field-imaging)
%                             datum_type: a video's from VideoReader's
%                             VideoFormat (RGB24/Grayscale -> uint8,
%                             RGB48/Mono16 -> uint16), a TIFF's from its
%                             header (imfinfo); unreadable -> skipped
%     opaque_body             the file, NOT held (decision #34): format,
%                             filename, size, modified time, MD5, and the
%                             file member body_data_0 recorded BY LOCATION
%                             (files.file_info.locations: the absolute path,
%                             location_type 'file', ingest 0) -- the bytes
%                             stay where they are until ingestion
%
%   OUT fields: documents (cell of structs), timeReferenceId, skipped
%   (cellstr: recordings not written, and why), subjectIds (containers.Map,
%   subject local_identifier -> document id, for stage 6), recordingRefs
%   (containers.Map, epoch -> the id of its UTC reference, for stages 9-10),
%   recordingStatements (containers.Map, epoch -> the id of its recording
%   statement, the input of stage 10's calculations).
%
%   Options:
%     'InstrumentIds'  containers.Map, spec key -> document id (from stage 2:
%                      camera_1, camera_2, axio_zoom_1). Missing keys leave
%                      instrument_id empty.
%     'Checksums'      default true: MD5 of every recording (reads every byte)
%     'ReadVideos'     default true: open each video (VideoReader) for its
%                      pixel format; false assumes uint8 (8-bit) without
%                      looking

arguments
    dataParentDir (1,:) char {mustBeFolder}
    session table
    S table
    R table
    options.InstrumentIds = containers.Map()
    options.Checksums (1,1) logical = true
    options.ReadVideos (1,1) logical = true
end

if height(session) ~= 1
    error('ndi:setup:conv:haley:oneSession', 'Give exactly one session row.');
end
sid = char(session.session_id{1});
if isempty(sid)
    error('ndi:setup:conv:haley:noSessionId', 'The session row has no session_id yet.');
end
sessionDocId = char(session.session_doc_id{1});
ref = char(session.local_identifier{1});
root = fullfile(dataParentDir, 'haley');
if ~startsWith(root, filesep) && isempty(regexp(root, '^[A-Za-z]:', 'once'))
    root = fullfile(pwd, root);   % a body records an ABSOLUTE location
end
tz = 'America/Los_Angeles';
S = S(strcmp(S.session, ref), :);
R = R(strcmp(R.session, ref), :);

docs = {};
out = struct('documents', {{}}, 'timeReferenceId', '', 'skipped', {{}}, ...
    'subjectIds', containers.Map(), 'recordingRefs', containers.Map(), ...
    'recordingStatements', containers.Map());

% ---- subjects ---------------------------------------------------------------
subjectIds = containers.Map();
hasType = ndi.setup.V2.schemaHasField('subject', 'type') && ismember('type', S.Properties.VariableNames);
for k = 1:height(S)
    f = struct('local_identifier', S.local_identifier{k}, 'name', S.name{k});
    if ~isempty(S.description{k})
        f.description = S.description{k};
    end
    if hasType                      % decision #55; did-schema #84
        f.type = did2.build.term('', S.type{k});
    end
    built = ndi.setup.V2.entityDocuments('subject', f, struct(), 'SessionId', sid);
    subjectIds(S.local_identifier{k}) = built{1}.base.id;
    docs = [docs, built]; %#ok<AGROW>
end

% ---- the session's own UTC extent -----------------------------------------
if height(R) > 0
    dur = R.duration;
    dur(isnan(dur)) = 0;
    t0 = min(R.local_start);
    t1 = max(R.local_start + seconds(dur));
    z0 = t0; z1 = t1;                    % elapsed time in the zone (daylight saving)
    if isempty(z0.TimeZone), z0.TimeZone = tz; end
    if isempty(z1.TimeZone), z1.TimeZone = tz; end
    d = utcReference(t0, seconds(z1 - z0), tz, sid);
    out.timeReferenceId = d.base.id;
    docs{end+1} = d;
end

% ---- acquisition systems ----------------------------------------------------
systems = unique(R.system, 'stable');
if ~isempty(systems)
    sw = struct();
    sw.system = softwareDoc('ndi.daq.system.image', sid);
    sw.navigator = softwareDoc('ndi.file.navigator.bodies', sid);
    sw.reader = softwareDoc('ndi.daq.reader.image.ndr', sid);
    docs = [docs, {sw.system, sw.navigator, sw.reader}];
end
readers = containers.Map();
channelIds = containers.Map();
for k = 1:numel(systems)
    sys = systems{k};
    [readerString, filePattern] = systemFiles(sys);
    if ~isKey(readers, readerString)
        d = did2.build.document('acquisition_reader', struct('reader_string', readerString), ...
            'SessionId', sid, 'Edges', struct('software_id', sw.reader.base.id));
        readers(readerString) = d.base.id;
        docs{end+1} = d; %#ok<AGROW>
    end
    pat = did2.build.document('epoch_file_pattern', struct( ...
        'file_pattern', {{filePattern}}, ...
        'epoch_map_format', 'ndi.epoch.epochprobemap_daqsystem'), ...
        'SessionId', sid, 'Edges', struct('software_id', sw.navigator.base.id));
    asys = did2.build.document('acquisition_system', struct('name', sys), 'SessionId', sid, ...
        'Edges', struct('software_id', sw.system.base.id, 'reader_id', readers(readerString), ...
        'epoch_file_pattern_id', pat.base.id));
    ch = did2.build.document('acquisition_channels', struct(), 'SessionId', sid, ...
        'Edges', struct('acquisition_system_id', asys.base.id));
    channelIds(sys) = ch.base.id;
    docs = [docs, {pat, asys, ch}]; %#ok<AGROW>
end

% ---- recordings: epoch, times, statement, body, files -----------------------
for k = 1:height(R)
    r = R(k, :);
    plate = r.plate{1};
    if ~isKey(subjectIds, plate)
        out.skipped{end+1} = sprintf('%s: plate %s is not a subject of this session', ...
            r.epoch{1}, plate);
        continue;
    end
    src = fullfile(root, r.file{1});
    [~, base, ext] = fileparts(src);
    [datumType, why] = datumTypeOf(src, ext, options.ReadVideos);
    if isempty(datumType)
        out.skipped{end+1} = sprintf('%s: %s', r.epoch{1}, why);
        continue;
    end

    isImage = strcmp(r.kind{1}, 'image');
    dur = r.duration;
    if isImage || isnan(dur)
        dur = [];
    end

    absRef = utcReference(r.local_start, dur, tz, sid);
    epochRefs = {absRef.base.id};
    if ~isImage
        relSession = did2.build.relativeTimeReference(sessionDocId, 'Clock', 'dev_local_time', ...
            'Start', 0, 'Duration', dur, 'SessionId', sid);
        epochRefs{end+1} = relSession.base.id; %#ok<AGROW>
        docs{end+1} = relSession; %#ok<AGROW>
    end
    ep = ndi.setup.V2.entityDocuments('epoch', struct('local_identifier', r.epoch{1}), ...
        struct('time_reference_id', {epochRefs}), 'SessionId', sid);
    ep = ep{1};
    if isImage
        relEpoch = did2.build.relativeTimeReference(ep.base.id, 'Relation', 'intervalDuring', 'SessionId', sid);
    else
        relEpoch = did2.build.relativeTimeReference(ep.base.id, 'Clock', 'dev_local_time', ...
            'Start', 0, 'Duration', dur, 'SessionId', sid);
    end

    instrumentKey = instrumentFor(r.system{1});
    instrumentId = '';
    if isKey(options.InstrumentIds, instrumentKey)
        instrumentId = options.InstrumentIds(instrumentKey);
    end
    st = did2.build.statement('intensity_observation', subjectIds(plate), ...
        did2.build.term('', 'image intensity'), [], 'DataBody', true, 'DatumType', datumType, ...
        'Method', did2.build.term('', probeType(r.system{1})), ...
        'InstrumentId', instrumentId, 'AcquisitionChannelsId', channelIds(r.system{1}), ...
        'TimeReferenceIds', {relEpoch.base.id, absRef.base.id}, 'SessionId', sid);

    info = dir(src);
    f = struct('format', mediaType(ext), 'filename', [base ext], ...
        'size_bytes', info.bytes, ...
        'file_modified', isoUtc(datetime(info.datenum, 'ConvertFrom', 'datenum', 'TimeZone', 'local')), ...
        'description', sprintf('The recording; the source table names it %s.', r.source_name{1}));
    if options.Checksums
        f.content_hash = ndi.fun.file.MD5(src);
        f.hash_algorithm = 'MD5';
    end
    body = did2.build.document('opaque_body', f, 'SessionId', sid, ...
        'Edges', struct('owner_id', st.base.id), 'Files', {'body_data_0'});
    % recorded BY LOCATION, not ingested (as ndi.document/add_file writes it)
    body.files.file_info = struct('name', 'body_data_0', 'locations', struct( ...
        'delete_original', 0, 'uid', ndi.ido.unique_id(), 'location', src, ...
        'parameters', '', 'location_type', 'file', 'ingest', 0));
    docs = [docs, {absRef, ep, relEpoch, st, body}]; %#ok<AGROW>
    out.recordingRefs(r.epoch{1}) = absRef.base.id;
    out.recordingStatements(r.epoch{1}) = st.base.id;

end
out.documents = docs;
out.subjectIds = subjectIds;
end

% -----------------------------------------------------------------------------
function [readerString, filePattern] = systemFiles(sys)
switch sys
    case 'camera1'
        readerString = 'video'; filePattern = '.*_1\.mp4\>';
    case 'camera2'
        readerString = 'video'; filePattern = '.*_2\.mp4\>';
    case 'microscope'
        readerString = 'tiffstack'; filePattern = '.*\.tiff\>';
    otherwise
        error('ndi:setup:conv:haley:unknownSystem', 'Unknown acquisition system "%s".', sys);
end
end

function key = instrumentFor(sys)
% acquisition system -> the dataset-level instrument subject's SPEC KEY (the
% key stage 2's id map uses; not its local_identifier, decision #59)
switch sys
    case 'microscope', key = 'axio_zoom_1';
    case 'camera1',    key = 'camera_1';
    case 'camera2',    key = 'camera_2';
    otherwise,         key = sys;
end
end

function t = probeType(sys)
% ndi_common/probe/probetype2object.json; all map to ndi.probe.image
if strcmp(sys, 'microscope')
    t = 'wide-field-imaging';
else
    t = 'brightfield-imaging';
end
end

function [t, why] = datumTypeOf(file, ext, readVideos)
% How the recording's pixel values are encoded (data_type.datum_type).
t = ''; why = '';
switch lower(ext)
    case '.mp4'
        if ~readVideos
            t = 'uint8';   % assumed ('ReadVideos', false): not opened
            return;
        end
        try
            v = VideoReader(file);
            fmt = v.VideoFormat;
        catch err
            why = sprintf('VideoReader cannot open it (%s)', err.message);
            return;
        end
        switch fmt
            case {'RGB24', 'Grayscale', 'Indexed', 'RGB24 Signed'}
                t = 'uint8';
            case {'RGB48', 'Mono16', 'RGB48 Signed', 'Mono16 Signed'}
                t = 'uint16';
            otherwise
                why = sprintf('video format %s has no datum_type mapping', fmt);
        end
    case {'.tif', '.tiff'}
        try
            info = imfinfo(file);
        catch err
            why = sprintf('cannot read the TIFF header (%s)', err.message);
            return;
        end
        bits = info(1).BitsPerSample(1);
        if isfield(info, 'SampleFormat') && strcmpi(info(1).SampleFormat, 'IEEE floating point')
            t = sprintf('float%d', bits);
        elseif any(bits == [8 16 32 64])
            t = sprintf('uint%d', bits);
        else
            why = sprintf('%d bits per sample has no datum_type', bits);
        end
end
end

function m = mediaType(ext)
switch lower(ext)
    case '.mp4',           m = 'video/mp4';
    case {'.tif', '.tiff'}, m = 'image/tiff';
    otherwise
        error('ndi:setup:conv:haley:unknownFormat', 'No media type for "%s".', ext);
end
end

function d = utcReference(localStart, dur, tz, sid)
t = localStart;
t.TimeZone = tz;
u = t;
u.TimeZone = 'UTC';
d = did2.build.absoluteTimeReference(char(u, 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''), ...
    'SourceValue', char(t, 'yyyy-MM-dd''T''HH:mm:ss'), 'SourceTimezone', tz, ...
    'Duration', dur, 'SessionId', sid);
end

function s = isoUtc(t)
% dir() reports the file time in this computer's own time zone
t.TimeZone = 'UTC';
s = char(t, 'yyyy-MM-dd''T''HH:mm:ss''Z''');
end

function d = softwareDoc(name, sid)
% a `software` entity (or, since 2026-10-08, an `entity` of type software)
d = ndi.setup.V2.entityDocuments('software', struct('name', name), struct(), 'SessionId', sid);
d = d{1};
end
