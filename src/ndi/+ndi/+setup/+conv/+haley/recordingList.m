function [R, checks] = recordingList(dataParentDir, sessions, options)
%RECORDINGLIST Stage 5 (Haley): the recordings, one epoch each, per session.
%
%   [R, CHECKS] = ndi.setup.conv.haley.recordingList(DATAPARENTDIR, SESSIONS)
%   reads the raw data under DATAPARENTDIR/haley and returns one row per
%   recording that has a file on disk, assigned to a session of SESSIONS
%   (the table from ndi.setup.conv.haley.sessionList). Decision log #27-#36.
%
%   C. elegans, from <folder>/experimentInfo.mat `info` and the session's
%   videos/<day> folder:
%     behaviour  `videoFileName` (an .avi name; disk holds the same-stem
%                .mp4). Extent from the table: numFrames / frameRate.
%     lawn       `lawnFileName`: the short clip of the plate before the worms
%                go in, shared by a plate's video rows. Its extent is read
%                from the file (VideoReader) only with 'ReadVideos', true.
%   E. coli, from ecoli/bacteria.mat `metaData` and ecoli/raw:
%     image      one per RAW image on disk (raw/<imageNum>.tiff: the
%                microscope images, extracted from analyzeGFP's `data` --
%                the 1,575 analysed and shared images and the 89 empty-plate
%                background images they were normalised by, decision #64);
%                an instant. The TIFFs in images/ are NOT recordings: each is
%                its raw image divided by its smoothed background
%                (analyzeLawnProfiles' imageNormalized, rounded), and the
%                calculations stage builds it as such. With no raw/ folder,
%                images/ is used as before and a check says the recordings
%                are background-normalised. Images with no file are not
%                recordings; each kept image's `note` names its background
%                and brightfield image.
%
%   Columns: session, kind, epoch (the epoch's local_identifier: the file
%   stem with the folder prefix, e.g. concentration_2022-02-04_12-10-51_1,
%   ecoli_image0002), system (camera1 / camera2 / microscope), plate (the
%   plate subject's local_identifier), file (relative to DATAPARENTDIR/haley),
%   source_name (the name the table records, e.g. the .avi), size_bytes,
%   local_start (the wall-clock start as recorded, no time zone),
%   n_frames, frame_rate, duration (seconds; NaN when not known), note,
%   temp and humidity (a behaviour video's `temp` (C) and `humidity` (%RH),
%   the probe's mean over the recording; NaN otherwise).
%
%   CHECKS (second output, also printed), nothing changed:
%     rowWithoutFile    a table row names a recording with no file on disk
%     fileWithoutRow    a video on disk no row names
%     cameraDisagrees   the `camera` column and the file name's _N disagree
%     noFrames          a behaviour row with numFrames or frameRate 0
%     imagesWithoutFile E. coli metaData images with no file, by kind
%     noRawImages       no ecoli/raw/ folder: the recordings fall back to the
%                       background-normalised TIFFs in images/
%     unreadable        'ReadVideos': a video VideoReader could not open
%     framesDisagree    'ReadVideos': a behaviour video whose decoded frame
%                       count differs from the table's numFrames (the
%                       decoded count is used)
%
%   Options:
%     'ReadVideos'  default false. true opens every lawn clip with MATLAB's
%                   VideoReader to read its frame count and rate (decision
%                   #30), and decodes every video once to measure the time
%                   of each frame (`frame_times`, decision #87): the videos
%                   do not have a constant frame rate, so frame k is not at
%                   (k-1)/frameRate (up to 1.33 s off over an hour).
%     'FrameTimesCache'  a .mat file that keeps the measured frame times
%                   between runs, keyed by file path, size and modification
%                   time ('' = none): decoding takes about 10 s per hour of
%                   video.

arguments
    dataParentDir (1,:) char {mustBeFolder}
    sessions table
    options.ReadVideos (1,1) logical = false
    options.FrameTimesCache (1,:) char = ''
end
cache = loadFrameTimes(options.FrameTimesCache);
nCached = cache.Count;

root = fullfile(dataParentDir, 'haley');
checks = struct('rowWithoutFile', {{}}, 'fileWithoutRow', {{}}, 'cameraDisagrees', {{}}, ...
    'noFrames', {{}}, 'imagesWithoutFile', {{}}, 'noRawImages', {{}}, 'unreadable', {{}}, ...
    'cameraSwap', {{}});
rows = {};
nFiles = 0;

% ---- C. elegans -------------------------------------------------------------
folders = unique(sessions.folder(~strcmp(sessions.folder, 'ecoli')));
for f = 1:numel(folders)
    folder = folders{f};
    pre = ndi.setup.conv.haley.idPrefix(folder);
    I = load(fullfile(root, 'celegans', folder, 'experimentInfo.mat'), 'info');
    I = I.info;
    nFiles = nFiles + 1;
    mine = sessions(strcmp(sessions.folder, folder), :);
    for s = 1:height(mine)
        vdir = mine.video_folder{s};
        onDisk = dir(fullfile(root, vdir, '*.mp4'));
        onDisk = {onDisk.name};
        used = false(size(onDisk));
        D = I(I.expNum == mine.experiment(s), :);
        seenLawn = {};
        for r = 1:height(D)
            plate = sprintf('%s_assayPlate%04d', pre, D.plateNum(r));
            % -- the behaviour video --
            src = strtrim(char(D.videoFileName{r}));
            if ~isempty(src)
                [~, stem] = fileparts(src);
                k = find(strcmp(onDisk, [stem '.mp4']), 1);
                if isempty(k)
                    msg = sprintf('%s: plate %d video %d names %s; no %s.mp4 in %s', ...
                        mine.local_identifier{s}, D.plateNum(r), D.videoNum(r), src, stem, vdir);
                    % a failed start (scale 0) whose plate has another video
                    % carries nothing measured: say so (decision #81)
                    if ismember('scale', D.Properties.VariableNames) && D.scale(r) == 0 && ...
                            sum(D.plateNum == D.plateNum(r)) > 1
                        msg = [msg '; it is a failed start (scale 0) and the plate''s ' ...
                            'other video holds its worms'];
                    end
                    checks.rowWithoutFile{end+1} = msg;
                else
                    used(k) = true;
                    cam = cameraOf(stem);
                    if ismember('camera', D.Properties.VariableNames) && D.camera(r) ~= cam
                        checks.cameraDisagrees{end+1} = sprintf('%s: %s is camera %d by name, %d in the table', ...
                            mine.local_identifier{s}, stem, cam, D.camera(r));
                    end
                    nf = D.numFrames(r); fr = D.frameRate(r);
                    dur = NaN;
                    if nf > 0 && fr > 0
                        dur = nf / fr;
                    else
                        checks.noFrames{end+1} = sprintf('%s: %s has numFrames %g, frameRate %g', ...
                            mine.local_identifier{s}, stem, nf, fr);
                    end
                    ft = [];
                    if options.ReadVideos
                        [ft, cache, err] = frameTimes(fullfile(root, vdir, [stem '.mp4']), cache);
                        if ~isempty(err)
                            checks.unreadable{end+1} = sprintf('%s: %s.mp4: %s', ...
                                mine.local_identifier{s}, stem, err);
                        elseif numel(ft) ~= nf
                            checks.framesDisagree{end+1} = sprintf(['%s: %s.mp4 decodes to %d ' ...
                                'frame(s); the table says %g'], mine.local_identifier{s}, stem, ...
                                numel(ft), nf);
                            nf = numel(ft);
                        end
                    end
                    row = recRow(mine.local_identifier{s}, 'behaviour', [pre '_' stem], ...
                        sprintf('camera%d', cam), plate, fullfile(vdir, [stem '.mp4']), src, ...
                        bytesOf(root, vdir, stem), D.timeRecord(r), nf, fr, dur);
                    row.frame_times = ft;
                    % the probe's readings for this recording (stage 9, decision #59)
                    row.temp = colValue(D, 'temp', r);
                    row.humidity = colValue(D, 'humidity', r);
                    rows{end+1} = row; %#ok<AGROW>
                end
            end
            % -- the lawn clip (one per plate, shared by its video rows) --
            if ismember('lawnFileName', D.Properties.VariableNames)
                src = strtrim(char(D.lawnFileName{r}));
                if ~isempty(src) && ~any(strcmp(seenLawn, src))
                    seenLawn{end+1} = src; %#ok<AGROW>
                    [~, stem] = fileparts(src);
                    k = find(strcmp(onDisk, [stem '.mp4']), 1);
                    if isempty(k)
                        checks.rowWithoutFile{end+1} = sprintf('%s: plate %d lawn clip %s; no %s.mp4 in %s', ...
                            mine.local_identifier{s}, D.plateNum(r), src, stem, vdir);
                    else
                        used(k) = true;
                        nf = NaN; fr = NaN; dur = NaN; ft = [];
                        if options.ReadVideos
                            [nf, fr, dur, err] = readVideo(fullfile(root, vdir, [stem '.mp4']));
                            if isempty(err)
                                [ft, cache, err] = frameTimes(fullfile(root, vdir, [stem '.mp4']), cache);
                                if isempty(err), nf = numel(ft); end
                            end
                            if ~isempty(err)
                                checks.unreadable{end+1} = sprintf('%s: %s.mp4: %s', ...
                                    mine.local_identifier{s}, stem, err);
                            end
                        end
                        row = recRow(mine.local_identifier{s}, 'lawn', [pre '_' stem], ...
                            sprintf('camera%d', cameraOf(stem)), plate, fullfile(vdir, [stem '.mp4']), ...
                            src, bytesOf(root, vdir, stem), stampOf(stem), nf, fr, dur);
                        row.frame_times = ft;
                        rows{end+1} = row; %#ok<AGROW>
                    end
                end
            end
        end
        % a plate whose lawn clip and video are on different cameras, when
        % no other plate that day changes camera (decision #83)
        here = find(cellfun(@(q) strcmp(q.session, mine.local_identifier{s}), rows));
        camOf = containers.Map();
        for q = here
            x = rows{q};
            camOf([x.plate '|' x.kind]) = x.system;
        end
        swapped = {};
        for q = here
            x = rows{q};
            if strcmp(x.kind, 'lawn') && isKey(camOf, [x.plate '|behaviour']) && ...
                    ~strcmp(camOf([x.plate '|behaviour']), x.system)
                swapped{end+1} = x.plate; %#ok<AGROW>
            end
        end
        for q = here
            x = rows{q};
            if any(strcmp(swapped, x.plate))
                rows{q}.note = sprintf(['This plate''s lawn clip and behaviour video were filmed on ' ...
                    'different cameras (%s, %s), as the source table names them; %d plate(s) ' ...
                    'did so that day. Whether the plates moved or the names were swapped is ' ...
                    'not known (decision #83).'], camOf([x.plate '|lawn']), ...
                    camOf([x.plate '|behaviour']), numel(swapped));
            end
        end
        for p = swapped
            checks.cameraSwap{end+1} = sprintf('%s: %s''s lawn clip and video are on different cameras; noted', ...
                mine.local_identifier{s}, p{1});
        end
        % worms all on listed plates: an unnamed file is not a missing plate
        allWorms = '';
        w = [];
        if ismember('wormNum', D.Properties.VariableNames)
            if iscell(D.wormNum)
                w = cell2mat(cellfun(@(v) reshape(double(v), 1, []), D.wormNum(:)', 'UniformOutput', false));
            else
                w = reshape(double(D.wormNum), 1, []);
            end
        end
        if ~isnan(mine.worm_first(s)) && ~isempty(w) && ...
                all(ismember(mine.worm_first(s):mine.worm_last(s), w))
            allWorms = sprintf(['; the day''s worms (%d-%d) are all on listed plates, so it is ' ...
                'not a missing plate'], mine.worm_first(s), mine.worm_last(s));
        end
        for k = find(~used)
            checks.fileWithoutRow{end+1} = sprintf('%s: %s is named by no row%s', ...
                mine.local_identifier{s}, fullfile(vdir, onDisk{k}), allWorms);
        end
    end
end

% ---- E. coli ----------------------------------------------------------------
mine = sessions(strcmp(sessions.folder, 'ecoli'), :);
if height(mine) > 0
    B = load(fullfile(root, 'ecoli', 'bacteria.mat'), 'metaData');
    M = B.metaData;
    % the images the lab analysed (one lawnAnalysis row per detected patch),
    % and the background images they were normalised against: a missing
    % file among these is a gap, any other is an acquisition never kept as
    % a TIFF (decision #79)
    w = whos('-file', fullfile(root, 'ecoli', 'bacteria.mat'));
    analysed = [];
    if any(strcmp({w.name}, 'lawnAnalysis'))
        A = load(fullfile(root, 'ecoli', 'bacteria.mat'), 'lawnAnalysis');
        analysed = unique(double(A.lawnAnalysis.imageNum));
        if ismember('backgroundImageNum', M.Properties.VariableNames)
            bgUsed = double(M.backgroundImageNum(ismember(M.imageNum, analysed)));
            analysed = union(analysed, bgUsed(~isnan(bgUsed)));
        end
    end
    nFiles = nFiles + 1;
    idir = fullfile('ecoli', 'raw');
    if ~isfolder(fullfile(root, idir))
        idir = fullfile('ecoli', 'images');
        checks.noRawImages{end+1} = ['ecoli: no raw/ folder; the recordings are the TIFFs in ' ...
            'images/, which are background-normalised, not as acquired (decision #64)'];
    end
    missing = 0; missingFluor = 0; missingUsed = 0;
    for r = 1:height(M)
        s = find(mine.experiment == double(M.expNum(r)), 1);
        if isempty(s)
            continue;
        end
        name = sprintf('%04d.tiff', M.imageNum(r));
        fi = dir(fullfile(root, idir, name));
        if isempty(fi)
            missing = missing + 1;
            missingUsed = missingUsed + ismember(double(M.imageNum(r)), analysed);
            if ismember('fluorescence', M.Properties.VariableNames) && M.fluorescence(r)
                missingFluor = missingFluor + 1;
            end
            continue;
        end
        src = '';
        if ismember('fileName', M.Properties.VariableNames)
            src = char(M.fileName{r});
        end
        note = imageNote(M, r);
        rows{end+1} = recRow(mine.local_identifier{s}, 'image', sprintf('ecoli_image%04d', M.imageNum(r)), ...
            'microscope', sprintf('ecoli_plate%04d', M.plateNum(r)), fullfile(idir, name), src, ...
            fi.bytes, M.acquisitionTime(r), 1, NaN, NaN, note); %#ok<AGROW>
    end
    if missing > 0
        if isempty(analysed)
            used = 'whether any was analysed is unknown (bacteria.mat has no lawnAnalysis)';
        elseif missingUsed == 0
            used = 'none was analysed or used as a background: acquisitions never kept as a TIFF';
        else
            used = sprintf('%d of them analysed or used as a background', missingUsed);
        end
        checks.imagesWithoutFile{end+1} = sprintf(['ecoli: %d of %d metaData image(s) have no file in ' ...
            '%s/ (%d of them fluorescence); %s'], missing, height(M), idir, missingFluor, used);
    end
end

% ---- report -------------------------------------------------------------------
if cache.Count > nCached
    saveFrameTimes(options.FrameTimesCache, cache);
end
if isempty(rows)
    R = cell2table(cell(0, 16), 'VariableNames', {'session', 'kind', 'epoch', 'system', ...
        'plate', 'file', 'source_name', 'size_bytes', 'local_start', 'n_frames', ...
        'frame_rate', 'duration', 'note', 'temp', 'humidity', 'frame_times'});
else
    R = struct2table([rows{:}], 'AsArray', true);
    [u, ~, j] = unique(R.epoch);
    dup = u(accumarray(j, 1) > 1);
    if ~isempty(dup)
        error('ndi:setup:conv:haley:duplicateEpoch', ...
            'Two recordings would share epoch %s.', strjoin(dup, ', '));
    end
end
kinds = {'behaviour', 'lawn', 'image'};
counts = cellfun(@(k) sum(strcmp(R.kind, k)), kinds);
gb = 0;
if height(R) > 0
    gb = sum(R.size_bytes, 'omitnan') / 1e9;
end
fprintf(['DENOMINATOR: %d recording(s) with a file, in %d session(s), from %d source table(s): ' ...
    '%d behaviour video(s), %d lawn clip(s), %d E. coli image(s); %.1f GB\n'], ...
    height(R), numel(unique(R.session)), nFiles, counts, gb);
names = fieldnames(checks);
fprintf('CHECKS (reported, nothing changed): %d finding(s)\n', ...
    sum(cellfun(@(n) numel(checks.(n)), names)));
for k = 1:numel(names)
    for m = 1:numel(checks.(names{k}))
        fprintf('  %-18s %s\n', names{k}, checks.(names{k}){m});
    end
end
end

% =============================================================================

function s = recRow(session, kind, epoch, system, plate, file, src, bytes, t, nf, fr, dur, note)
if nargin < 13
    note = '';
end
% One kind of value for the whole column: the sources mix zoned and unzoned
% datetimes (which cannot be concatenated), so a zoned one is expressed in
% the lab's time zone and its zone dropped -- `local_start` is wall-clock time.
if ~isempty(t.TimeZone)
    t.TimeZone = 'America/Los_Angeles';
    t.TimeZone = '';
end
t.Format = 'dd-MMM-yyyy HH:mm:ss';
s = struct('session', session, 'kind', kind, 'epoch', epoch, 'system', system, ...
    'plate', plate, 'file', file, 'source_name', src, 'size_bytes', double(bytes), ...
    'local_start', t, 'n_frames', double(nf), 'frame_rate', double(fr), 'duration', double(dur), ...
    'note', note, 'temp', NaN, 'humidity', NaN, 'frame_times', []);
% frame_times: the measured time of each frame, seconds from the start of the
% file (a column), or [] when the video was not decoded. In the table it is a
% cell column; read a row with private/frameTimesOf.
end

function v = colValue(D, name, r)
% D.(NAME)(R) as a double, NaN when the table has no such column
v = NaN;
if ismember(name, D.Properties.VariableNames)
    v = double(D.(name)(r));
end
end

function note = imageNote(M, r)
% The processing facts an image file cannot carry: its exposure, and the
% background and brightfield images it was paired with (by imageNum; those
% images were not shared as files).
parts = {};
if ismember('exposureTime', M.Properties.VariableNames)
    parts{end+1} = sprintf('exposure %g ms', M.exposureTime(r));
end
if ismember('backgroundImageNum', M.Properties.VariableNames) && ~isnan(M.backgroundImageNum(r))
    parts{end+1} = sprintf('background image %d', M.backgroundImageNum(r));
end
if ismember('brightfieldImageNum', M.Properties.VariableNames) && ~isnan(M.brightfieldImageNum(r))
    parts{end+1} = sprintf('brightfield image %d', M.brightfieldImageNum(r));
end
note = strjoin(parts, '; ');
end

function c = cameraOf(stem)
% The camera is the file name's last _N (2022-02-04_12-10-51_1 -> 1).
tok = regexp(stem, '_(\d+)$', 'tokens', 'once');
c = NaN;
if ~isempty(tok)
    c = str2double(tok{1});
end
end

function t = stampOf(stem)
% The wall-clock start in the name: yyyy-MM-dd_HH-mm-ss_N.
tok = regexp(stem, '^(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})', 'tokens', 'once');
t = NaT;
if ~isempty(tok)
    t = datetime(tok{1}, 'InputFormat', 'yyyy-MM-dd_HH-mm-ss');
end
end

function b = bytesOf(root, vdir, stem)
d = dir(fullfile(root, vdir, [stem '.mp4']));
b = NaN;
if ~isempty(d)
    b = d.bytes;
end
end

function [t, cache, err] = frameTimes(file, cache)
% The measured time of every frame of a video (decision #87): VideoReader's
% CurrentTime just before each readFrame, in seconds from the start of the
% file -- the method of NDR's ndr.reader.video/frametimes, so the times agree
% with what NDI reads. Cached by path, size and modification time.
t = []; err = '';
d = dir(file);
if isempty(d)
    err = 'no such file';
    return;
end
key = sprintf('%s|%d|%.10f', file, d(1).bytes, d(1).datenum);
if isKey(cache, key)
    t = cache(key);
    return;
end
try
    v = VideoReader(file);
    n = v.NumFrames;
    if isempty(n) || ~isfinite(n) || n < 1, n = 0; end
    t = zeros(n, 1);
    k = 0;
    while hasFrame(v)
        k = k + 1;
        t(k, 1) = v.CurrentTime;
        readFrame(v);
    end
    t = t(1:k);
    cache(key) = t;
catch e
    t = [];
    err = e.message;
end
end

function cache = loadFrameTimes(file)
cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
if isempty(file) || ~isfile(file), return; end
S = load(file, 'frameTimes');
if isfield(S, 'frameTimes') && isa(S.frameTimes, 'containers.Map')
    cache = S.frameTimes;
end
end

function saveFrameTimes(file, cache)
if isempty(file), return; end
folder = fileparts(file);
if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
frameTimes = cache; %#ok<NASGU>
save(file, 'frameTimes', '-v7.3');
end

function [nf, fr, dur, err] = readVideo(file)
nf = NaN; fr = NaN; dur = NaN; err = '';
try
    v = VideoReader(file);
    nf = v.NumFrames;
    fr = v.FrameRate;
    dur = v.Duration;
catch e
    err = e.message;
end
end
