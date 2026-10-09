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
%     unreadable        'ReadVideos': a lawn clip VideoReader could not open
%
%   Options:
%     'ReadVideos'  default false. true opens every lawn clip with MATLAB's
%                   VideoReader to read its frame count and rate (decision
%                   #30); behaviour videos are not opened.

arguments
    dataParentDir (1,:) char {mustBeFolder}
    sessions table
    options.ReadVideos (1,1) logical = false
end

root = fullfile(dataParentDir, 'haley');
checks = struct('rowWithoutFile', {{}}, 'fileWithoutRow', {{}}, 'cameraDisagrees', {{}}, ...
    'noFrames', {{}}, 'imagesWithoutFile', {{}}, 'noRawImages', {{}}, 'unreadable', {{}});
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
                    checks.rowWithoutFile{end+1} = sprintf('%s: plate %d video %d names %s; no %s.mp4 in %s', ...
                        mine.local_identifier{s}, D.plateNum(r), D.videoNum(r), src, stem, vdir);
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
                    row = recRow(mine.local_identifier{s}, 'behaviour', [pre '_' stem], ...
                        sprintf('camera%d', cam), plate, fullfile(vdir, [stem '.mp4']), src, ...
                        bytesOf(root, vdir, stem), D.timeRecord(r), nf, fr, dur);
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
                        nf = NaN; fr = NaN; dur = NaN;
                        if options.ReadVideos
                            [nf, fr, dur, err] = readVideo(fullfile(root, vdir, [stem '.mp4']));
                            if ~isempty(err)
                                checks.unreadable{end+1} = sprintf('%s: %s.mp4: %s', ...
                                    mine.local_identifier{s}, stem, err);
                            end
                        end
                        rows{end+1} = recRow(mine.local_identifier{s}, 'lawn', [pre '_' stem], ...
                            sprintf('camera%d', cameraOf(stem)), plate, fullfile(vdir, [stem '.mp4']), ...
                            src, bytesOf(root, vdir, stem), stampOf(stem), nf, fr, dur); %#ok<AGROW>
                    end
                end
            end
        end
        for k = find(~used)
            checks.fileWithoutRow{end+1} = sprintf('%s: %s is named by no row', ...
                mine.local_identifier{s}, fullfile(vdir, onDisk{k}));
        end
    end
end

% ---- E. coli ----------------------------------------------------------------
mine = sessions(strcmp(sessions.folder, 'ecoli'), :);
if height(mine) > 0
    B = load(fullfile(root, 'ecoli', 'bacteria.mat'), 'metaData');
    M = B.metaData;
    nFiles = nFiles + 1;
    idir = fullfile('ecoli', 'raw');
    if ~isfolder(fullfile(root, idir))
        idir = fullfile('ecoli', 'images');
        checks.noRawImages{end+1} = ['ecoli: no raw/ folder; the recordings are the TIFFs in ' ...
            'images/, which are background-normalised, not as acquired (decision #64)'];
    end
    missing = 0; missingFluor = 0;
    for r = 1:height(M)
        s = find(mine.experiment == double(M.expNum(r)), 1);
        if isempty(s)
            continue;
        end
        name = sprintf('%04d.tiff', M.imageNum(r));
        fi = dir(fullfile(root, idir, name));
        if isempty(fi)
            missing = missing + 1;
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
        checks.imagesWithoutFile{end+1} = sprintf(['ecoli: %d of %d metaData image(s) have no file in ' ...
            '%s/ (%d of them fluorescence)'], missing, height(M), idir, missingFluor);
    end
end

% ---- report -------------------------------------------------------------------
if isempty(rows)
    R = cell2table(cell(0, 15), 'VariableNames', {'session', 'kind', 'epoch', 'system', ...
        'plate', 'file', 'source_name', 'size_bytes', 'local_start', 'n_frames', ...
        'frame_rate', 'duration', 'note', 'temp', 'humidity'});
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
    'note', note, 'temp', NaN, 'humidity', NaN);
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
