function out = sessionDocuments(dataParentDir, session, S, R, options)
%SESSIONDOCUMENTS Stages 4-5 (Haley), written: every document for ONE session.
%
%   OUT = ndi.setup.conv.haley.sessionDocuments(DATAPARENTDIR, SESSION, S, R)
%   builds, for the one-row session table SESSION (from sessionList, with
%   `session_id` already assigned), the V2 documents of its subjects (S rows,
%   from subjectList) and recordings (R rows, from recordingList), plus the
%   files the session folder needs so NDI's file navigator finds each
%   recording. Nothing is written here: ndi.setup.V2.makeSessions writes the
%   documents and ndi.setup.V2.placeFiles the links and probe maps.
%   Decision log #28-#35, #45-#49.
%
%   Documents, all with base.session_id = SESSION.session_id:
%     subject                 one per S row (local_identifier, name, description)
%     absolute_time_reference the session's UTC extent (first recording start
%                             to last recording end); OUT.timeReferenceId, for
%                             session.time_reference_id
%     software                the three NDI classes an acquisition system is
%                             rebuilt from (decision #29): ndi.daq.system.image,
%                             ndi.file.navigator.epochdir, ndi.daq.reader.image.ndr
%     acquisition_reader      one per reader string: 'video' (cameras),
%                             'tiffstack' (microscope)
%     epoch_file_pattern      one per system: its file in each epoch folder
%     acquisition_system      one per system in the session (camera1, camera2,
%                             microscope; decision #28)
%     acquisition_channels    one per system (no channel numbers: a camera has
%                             no ai/ao/di/do channels, the only types the
%                             schema binds)
%   and per recording (R row):
%     epoch                   local_identifier = R.epoch = the epoch folder
%                             name, so NDI's epoch id and the document agree
%     relative_time_reference dev_local_time from 0 for the recording's
%                             duration, referent the SESSION document (videos)
%     absolute_time_reference its UTC start (and duration when known)
%     intensity_observation   the recording: subject = the plate, instrument =
%                             the dataset-level camera / microscope subject
%                             (when 'InstrumentIds' has it), acquisition
%                             channels = this session's system; times = a
%                             relative reference to the EPOCH (videos: the
%                             same extent; images: `during`) + the UTC one
%                             datum_type: a video's from VideoReader's
%                             VideoFormat (RGB24/Grayscale -> uint8,
%                             RGB48/Mono16 -> uint16), a TIFF's from its
%                             header (imfinfo); unreadable -> skipped
%     opaque_body             the file, NOT held (decision #34): format,
%                             filename, size, modified time, MD5; the raw
%                             location is in `description`
%
%   OUT fields: documents (cell of structs), timeReferenceId, links (struct
%   array source/target, absolute paths), texts (struct array file/text),
%   skipped (cellstr: recordings with no plate subject in this session).
%
%   Options:
%     'InstrumentIds'  containers.Map, instrument key -> document id (from
%                      stage 2: camera1, camera2, axiozoom1). Missing keys
%                      leave instrument_id empty.
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
tz = 'America/Los_Angeles';
S = S(strcmp(S.session, ref), :);
R = R(strcmp(R.session, ref), :);

docs = {};
out = struct('documents', {{}}, 'timeReferenceId', '', ...
    'links', struct('source', {}, 'target', {}), ...
    'texts', struct('file', {}, 'text', {}), 'skipped', {{}});

% ---- subjects ---------------------------------------------------------------
subjectIds = containers.Map();
for k = 1:height(S)
    f = struct('local_identifier', S.local_identifier{k}, 'name', S.name{k});
    if ~isempty(S.description{k})
        f.description = S.description{k};
    end
    d = did2.build.document('subject', f, 'SessionId', sid);
    subjectIds(S.local_identifier{k}) = d.base.id;
    docs{end+1} = d; %#ok<AGROW>
end

% ---- the session's own UTC extent -----------------------------------------
if height(R) > 0
    dur = R.duration;
    dur(isnan(dur)) = 0;
    t0 = min(R.local_start);
    t1 = max(R.local_start + seconds(dur));
    d = utcReference(t0, seconds(t1 - t0), tz, sid);
    out.timeReferenceId = d.base.id;
    docs{end+1} = d;
end

% ---- acquisition systems ----------------------------------------------------
systems = unique(R.system, 'stable');
if ~isempty(systems)
    sw = struct();
    sw.system = did2.build.document('software', struct('name', 'ndi.daq.system.image'), 'SessionId', sid);
    sw.navigator = did2.build.document('software', struct('name', 'ndi.file.navigator.epochdir'), 'SessionId', sid);
    sw.reader = did2.build.document('software', struct('name', 'ndi.daq.reader.image.ndr'), 'SessionId', sid);
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
        'file_pattern', {{filePattern, '.*\.epochprobemap\.ndi\>'}}, ...
        'epoch_map_pattern', {{'.*\.epochprobemap\.ndi\>'}}, ...
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
    ep = did2.build.document('epoch', struct('local_identifier', r.epoch{1}), 'SessionId', sid, ...
        'Edges', struct('time_reference_id', {epochRefs}));
    if isImage
        relEpoch = did2.build.relativeTimeReference(ep.base.id, 'Relation', 'during', 'SessionId', sid);
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
        'InstrumentId', instrumentId, 'AcquisitionChannelsId', channelIds(r.system{1}), ...
        'TimeReferenceIds', {relEpoch.base.id, absRef.base.id}, 'SessionId', sid);

    info = dir(src);
    f = struct('format', mediaType(ext), 'filename', [base ext], ...
        'size_bytes', info.bytes, ...
        'file_modified', isoUtc(datetime(info.datenum, 'ConvertFrom', 'datenum', 'TimeZone', 'local')), ...
        'description', sprintf(['Not held in the database: the file is at haley/%s ' ...
            '(the source table names it %s).'], strrep(r.file{1}, '\', '/'), r.source_name{1}));
    if options.Checksums
        f.content_hash = ndi.fun.file.MD5(src);
        f.hash_algorithm = 'MD5';
    end
    body = did2.build.document('opaque_body', f, 'SessionId', sid, ...
        'Edges', struct('owner_id', st.base.id));
    docs = [docs, {absRef, ep, relEpoch, st, body}]; %#ok<AGROW>

    % the session folder: <session>/<epoch>/<file> + its probe map
    epochDir = fullfile(char(session.path{1}), r.epoch{1});
    out.links(end+1) = struct('source', src, 'target', fullfile(epochDir, [base ext]));
    out.texts(end+1) = struct('file', fullfile(epochDir, [base '.epochprobemap.ndi']), ...
        'text', sprintf('name\treference\ttype\tdevicestring\tsubjectstring\n%s\t1\t%s\t%s:image1\t%s\n', ...
        r.system{1}, probeType(r.system{1}), r.system{1}, subjectIds(plate)));
end
out.documents = docs;
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
% acquisition system -> the dataset-level instrument subject's spec key
if strcmp(sys, 'microscope')
    key = 'axiozoom1';
else
    key = sys;
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
