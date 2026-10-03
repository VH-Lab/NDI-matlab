function [T, checks] = sessionList(dataParentDir, spec, options)
%SESSIONLIST Stage 3 (Haley): the sessions to create, one per experiment.
%
%   T = ndi.setup.conv.haley.sessionList(DATAPARENTDIR, SPEC) reads the raw
%   data under DATAPARENTDIR/haley and returns one row per session, ready for
%   ndi.setup.V2.makeSessions (decision log entries 5, 21-24):
%
%     C. elegans  one row per row of <study folder>/tableOfContents.xlsx,
%                 i.e. one per experiment day. The row's study is found from
%                 SPEC.studies by `source_folder`, and for foragingConcentration
%                 (two studies in one folder) by the FIRST WORD of the row's
%                 `conditions` (`grid` / `single`) against `source_condition`.
%     E. coli     one row per `expNum` in ecoli/bacteria.mat (entry 23), dated
%                 by that experiment's earliest image (`metaData.acquisitionTime`).
%
%   Columns: local_identifier (e.g. concentration_0001; the prefix is
%   ndi.setup.conv.haley.idPrefix of the folder), name, description
%   (notebook, conditions, worm range, inclusion, notes), path
%   (OUTPUTROOT/<prefix>/<local_identifier>), study_key, study_ids, source,
%   folder, video_folder (C. elegans: celegans/<folder>/videos/<directoryName>,
%   relative to DATAPARENTDIR/haley; '' for E. coli), experiment, date,
%   include, worm_first, worm_last.
%
%   CHECKS (second output, also printed) reports what looks wrong in the
%   source's own day index, WITHOUT changing anything:
%     sharedDay        sessions of one study with the same directoryName (a
%                      copy-down in the spreadsheet: foragingMatching had all
%                      five rows at 23-02-24, 2026-09-30)
%     noVideoFolder    sessions whose videos/<directoryName> folder is missing
%     unusedVideoDay   video folders no session points at
%     ecoliSpread      E. coli experiments whose images span more than 14 days
%                      (a stray timestamp would move the session's date)
%
%   The tableOfContents worm range is kept (worm_first / worm_last) but NOT
%   trusted: the subjects stage cross-checks it against the worms present
%   (decision 3; foragingConcentration row 0014 is a known typo).
%
%   Options:
%     'StudyIds'    containers.Map, study key -> study document id (from stage
%                   2); when given, `study_ids` is filled in
%     'OutputRoot'  where session directories go (default: <DATAPARENTDIR>/haley_V2)
%
%   Errors ndi:setup:conv:haley:* when a tableOfContents lacks a required
%   column, or a row matches no study or more than one.

arguments
    dataParentDir (1,:) char {mustBeFolder}
    spec (1,1) struct
    options.StudyIds = containers.Map()
    options.OutputRoot (1,:) char = ''
end

root = fullfile(dataParentDir, 'haley');
outRoot = options.OutputRoot;
if isempty(outRoot)
    outRoot = fullfile(dataParentDir, 'haley_V2');
end
studies = asCell(spec.studies);
rows = {};
checks = struct('sharedDay', {{}}, 'noVideoFolder', {{}}, 'unusedVideoDay', {{}}, ...
    'ecoliSpread', {{}});

% ---- C. elegans: the tableOfContents of each study folder ------------------
folders = unique(cellfun(@(s) char(s.source_folder), studies, 'UniformOutput', false));
folders = folders(~strcmp(folders, 'ecoli'));
need = {'experimentNumber', 'directoryName', 'notebookName', 'wormNumber', ...
    'conditions', 'include', 'notes'};
for f = 1:numel(folders)
    folder = folders{f};
    toc = fullfile(root, 'celegans', folder, 'tableOfContents.xlsx');
    if ~isfile(toc)
        error('ndi:setup:conv:haley:noTableOfContents', 'Missing %s.', toc);
    end
    opts = detectImportOptions(toc);
    opts = setvartype(opts, 'char');
    C = readtable(toc, opts);
    missing = setdiff(need, C.Properties.VariableNames);
    if ~isempty(missing)
        error('ndi:setup:conv:haley:badTableOfContents', '%s has no column(s) %s.', ...
            toc, strjoin(missing, ', '));
    end
    seenDays = {};
    for r = 1:height(C)
        if isempty(strtrim(C.experimentNumber{r}))
            continue;   % a blank spreadsheet row
        end
        dayDir = strtrim(C.directoryName{r});
        if any(strcmp(seenDays, dayDir))
            checks.sharedDay{end+1} = sprintf('%s: experiment %s shares directoryName %s with an earlier row', ...
                folder, strtrim(C.experimentNumber{r}), dayDir);
        end
        seenDays{end+1} = dayDir; %#ok<AGROW>
        if ~isfolder(fullfile(root, 'celegans', folder, 'videos', dayDir))
            checks.noVideoFolder{end+1} = sprintf('%s: experiment %s -> videos/%s does not exist', ...
                folder, strtrim(C.experimentNumber{r}), dayDir);
        end
        n = str2double(C.experimentNumber{r});
        cond = strtrim(C.conditions{r});
        word = lower(strtok(cond));
        study = pickStudy(studies, folder, word, toc, r);
        day = datetime(strtrim(C.directoryName{r}), 'InputFormat', 'yy-MM-dd');
        [w1, w2] = wormRange(C.wormNumber{r});
        include = ~strcmpi(strtrim(C.include{r}), 'no');
        desc = sprintf('Lab notebook: %s. Conditions: %s. Worms: %s. Included in analysis: %s.', ...
            strtrim(C.notebookName{r}), cond, strtrim(C.wormNumber{r}), yesNo(include));
        if ~isempty(strtrim(C.notes{r}))
            desc = sprintf('%s Notes: %s.', desc, strtrim(C.notes{r}));
        end
        pre = ndi.setup.conv.haley.idPrefix(folder);
        id = sprintf('%s_%04d', pre, n);
        rows{end+1} = row(id, study, n, day, desc, include, w1, w2, ...
            fullfile(outRoot, pre, id), ['tableOfContents ' folder], folder, ...
            fullfile('celegans', folder, 'videos', dayDir), options.StudyIds); %#ok<AGROW>
    end
    v = dir(fullfile(root, 'celegans', folder, 'videos'));
    v = {v([v.isdir] & ~startsWith({v.name}, '.')).name};
    unused = setdiff(v, seenDays);
    for k = 1:numel(unused)   % by index: a 0x1 cell would still run a `for u = ...` loop once
        checks.unusedVideoDay{end+1} = sprintf('%s: videos/%s is not named by any tableOfContents row', ...
            folder, unused{k});
    end
end

% ---- E. coli: one session per expNum --------------------------------------
if any(cellfun(@(s) strcmp(char(s.source_folder), 'ecoli'), studies))
    bfile = fullfile(root, 'ecoli', 'bacteria.mat');
    B = load(bfile, 'info', 'metaData');
    study = pickStudy(studies, 'ecoli', '', bfile, 0);
    exps = unique(B.info.expNum);
    for e = 1:numel(exps)
        n = exps(e);
        plates = unique(B.info.plateNum(B.info.expNum == n));
        t = B.metaData.acquisitionTime(B.metaData.expNum == n);
        if isempty(t)
            day = NaT;
            desc = sprintf('%d plate(s); no images recorded in metaData.', numel(plates));
        else
            day = dateshift(min(t), 'start', 'day');
            if max(t) - min(t) > days(14)
                checks.ecoliSpread{end+1} = sprintf(['ecoli experiment %d: images span %s to %s; ' ...
                    'the session is dated by the earliest'], n, char(min(t), 'yyyy-MM-dd'), ...
                    char(max(t), 'yyyy-MM-dd'));
            end
            desc = sprintf('%d plate(s) imaged; %d image(s) from %s to %s.', numel(plates), ...
                numel(t), char(min(t), 'yyyy-MM-dd HH:mm'), char(max(t), 'yyyy-MM-dd HH:mm'));
        end
        id = sprintf('ecoli_%04d', n);
        rows{end+1} = row(id, study, n, day, desc, true, NaN, NaN, ...
            fullfile(outRoot, 'ecoli', id), 'bacteria.mat', 'ecoli', '', options.StudyIds); %#ok<AGROW>
    end
end

T = struct2table([rows{:}], 'AsArray', true);
fprintf('DENOMINATOR: %d session(s): %d C. elegans from %d tableOfContents file(s), %d E. coli\n', ...
    height(T), sum(~startsWith(T.local_identifier, 'ecoli_')), numel(folders), ...
    sum(startsWith(T.local_identifier, 'ecoli_')));
names = fieldnames(checks);
fprintf('CHECKS (reported, nothing changed): %d finding(s)\n', ...
    sum(cellfun(@(n) numel(checks.(n)), names)));
for k = 1:numel(names)
    for m = 1:numel(checks.(names{k}))
        fprintf('  %-15s %s\n', names{k}, checks.(names{k}){m});
    end
end
end

% =============================================================================

function s = row(id, study, n, day, desc, include, w1, w2, path, source, folder, videoFolder, studyIds)
if isnat(day)
    when = 'date unknown';
else
    when = char(day, 'd MMM yyyy');
end
ids = {};
if isKey(studyIds, char(study.key))
    ids = {studyIds(char(study.key))};
end
s = struct('local_identifier', id, ...
    'name', sprintf('%s, experiment %d (%s)', char(study.name), n, when), ...
    'description', desc, 'path', path, 'study_key', char(study.key), ...
    'study_ids', {ids}, 'source', source, 'folder', folder, 'video_folder', videoFolder, ...
    'experiment', n, 'date', day, ...
    'include', include, 'worm_first', w1, 'worm_last', w2);
end

function study = pickStudy(studies, folder, word, where, r)
hit = {};
for k = 1:numel(studies)
    s = studies{k};
    if ~strcmp(char(s.source_folder), folder)
        continue;
    end
    if isfield(s, 'source_condition') && ~isempty(s.source_condition) ...
            && ~strcmpi(char(s.source_condition), word)
        continue;
    end
    hit{end+1} = s; %#ok<AGROW>
end
if numel(hit) ~= 1
    error('ndi:setup:conv:haley:noStudy', ...
        '%s row %d (folder %s, condition "%s") matches %d studies in the spec, not 1.', ...
        where, r, folder, word, numel(hit));
end
study = hit{1};
end

function [a, b] = wormRange(txt)
a = NaN; b = NaN;
tok = regexp(strtrim(txt), '^(\d+)\s*-\s*(\d+)$', 'tokens', 'once');
if ~isempty(tok)
    a = str2double(tok{1});
    b = str2double(tok{2});
end
end

function s = yesNo(tf)
if tf, s = 'yes'; else, s = 'no'; end
end

function c = asCell(v)
if iscell(v), c = reshape(v, 1, []); else, c = num2cell(reshape(v, 1, [])); end
end
