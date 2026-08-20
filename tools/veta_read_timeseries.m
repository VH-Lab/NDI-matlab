function veta_read_timeseries(sessionPath, options)
%VETA_READ_TIMESERIES Read signal from a migrated V_eta session, step by step.
%
%   veta_read_timeseries(SESSIONPATH)
%   veta_read_timeseries(SESSIONPATH, 'Element', 'electrode16')
%   veta_read_timeseries(SESSIONPATH, 'Epoch', 1, 'T0', 0, 'T1', 1)
%
%   The half `veta_open_migrated_session` deliberately does NOT attempt.
%   That one proves the documents rebuild as NDI objects; this one proves
%   the objects can reach the bytes, which is a different claim and needs
%   the raw data files present beside the session.
%
%   WHY IT IS ITS OWN SCRIPT, AND WHY IT GOES ONE STEP AT A TIME
%   -----------------------------------------------------------
%   `readtimeseries` sits on top of four things that can each be wrong
%   independently, and when it fails it usually fails at the bottom while
%   erroring at the top. So each layer is checked and PRINTED before the
%   next is attempted:
%
%     1. the element rebuilds as an object          (the vintage map)
%     2. `direct` is TRUE                           (see below -- load-bearing)
%     3. the epoch table is non-empty               (the file navigator finds
%                                                    the raw files on disk)
%     4. the epoch carries an `epochprobemap`       (which channels are mine)
%     5. only then, the read itself
%
%   STEP 2 IS THE ONE THAT WAS BROKEN UNTIL 2026-08-14, and it fails
%   QUIETLY: `ndi.element.epochtable` gives a NON-DIRECT element
%   `epochprobemap = []` (element.m:342), so a recording probe that read
%   back as `direct = 0` would produce an epoch table with no channel map
%   and a read that finds nothing -- with no error anywhere. If you see
%   `direct: 0` on a recording probe here, stop: the fault is in the read
%   path (ndi.vintage.elementFields), not in your files.
%
%   THE FILES HAVE TO BE THERE. The published corpus zips are
%   document-only -- `find <corpus> -type f | grep -vc '\.json$'` is 0 for
%   PRED, 20211116, Dab and Soph -- so this script does nothing useful on
%   them. It needs a real session directory with its `.rhd` (or other
%   acquisition) files in place.
%
%   NOTHING IS WRITTEN. This opens the session read-only and does not
%   migrate; run `veta_open_migrated_session` first if the V_eta database
%   does not exist yet.

arguments
    sessionPath (1,:) char
    options.Element (1,:) char = ''      % name; default = every element
    options.Epoch (1,1) double = 1
    options.T0 (1,1) double = 0
    options.T1 (1,1) double = 1          % ONE SECOND, not inf -- see below
end

sessionPath = localExpandTilde(sessionPath);

fprintf('\n=== V_eta readtimeseries walkthrough ===\n');
fprintf('session path: %s\n', sessionPath);

s = ndi.session.dir(sessionPath);
db = ndi.database.fun.opendatabase(fullfile(sessionPath, '.ndi'), s.id());
fprintf('  database backend : %s\n', class(db));
if ~isa(db, 'ndi.database.implementations.database.did2sqlite')
    fprintf('  *** NOT did2sqlite -- this is the PRE-migration database.\n');
end

els = s.getelements();
if isempty(els); els = {}; elseif ~iscell(els); els = {els}; end
if ~isempty(options.Element)
    keep = cellfun(@(e) strcmp(e.name, options.Element), els);
    els = els(keep);
end
fprintf('  DENOMINATOR: %d element(s) to try\n', numel(els));
if isempty(els)
    fprintf('  nothing to read. `getelements` returned none matching.\n');
    return;
end

for i = 1:numel(els)
    e = els{i};
    fprintf('\n--- [%d] %s (%s) ---\n', i, e.name, class(e));

    % ---- 2. direct -----------------------------------------------------
    fprintf('  direct     : %d\n', e.direct);
    if ~e.direct
        fprintf(['  *** direct is 0. `epochtable` will return ' ...
                 'epochprobemap = [] for this\n      element ' ...
                 '(element.m:342), so no channel map and no read. If ' ...
                 'this is a\n      RECORDING probe, the fault is the ' ...
                 'read path, not your files --\n      see ' ...
                 'ndi.vintage.elementFields.\n']);
    end

    if ~ismethod(e, 'readtimeseries')
        fprintf('  no readtimeseries method on %s -- skipping.\n', class(e));
        continue;
    end

    % ---- 3. the epoch table -------------------------------------------
    % WRAPPED, because this is where a missing raw file surfaces and the
    % message is about a navigator rather than about a file.
    try
        et = e.epochtable();
    catch err
        fprintf('  *** epochtable FAILED: %s\n      (%s)\n', ...
            err.message, err.identifier);
        fprintf(['      This is usually the file navigator not finding ' ...
                 'the raw files.\n      Check they are under %s\n'], ...
            sessionPath);
        continue;
    end
    fprintf('  DENOMINATOR: %d epoch(s) in the epoch table\n', numel(et));
    if isempty(et)
        fprintf(['  *** ZERO epochs. The navigator found no matching ' ...
                 'files. Nothing to read.\n']);
        continue;
    end

    n = min(options.Epoch, numel(et));
    fprintf('  reading epoch %d of %d (id: %s)\n', n, numel(et), ...
        localShort(et(n).epoch_id));

    % ---- 4. the channel map -------------------------------------------
    if isfield(et(n), 'epochprobemap') && ~isempty(et(n).epochprobemap)
        fprintf('  epochprobemap: %d entr(ies)\n', numel(et(n).epochprobemap));
    else
        fprintf(['  *** epochprobemap is EMPTY. For a direct probe this ' ...
                 'means the map file\n      was not found or not ' ...
                 'parsed; for direct = 0 it is expected and is\n' ...
                 '      the earlier fault.\n']);
    end

    % ---- 5. the read ---------------------------------------------------
    % T1 DEFAULTS TO 1 SECOND, NOT inf, ON PURPOSE. A whole epoch of
    % multichannel ephys is easily gigabytes, and the question here is
    % "does the path work", which one second answers exactly as well.
    fprintf('  readtimeseries(epoch %d, t0=%g, t1=%g) ...\n', ...
        n, options.T0, options.T1);
    try
        [d, t] = e.readtimeseries(n, options.T0, options.T1);
    catch err
        fprintf('  *** readtimeseries FAILED: %s\n      (%s)\n', ...
            err.message, err.identifier);
        continue;
    end

    fprintf('  DATA : %s %s\n', mat2str(size(d)), class(d));
    if isnumeric(t)
        fprintf('  TIME : %s %s', mat2str(size(t)), class(t));
        if ~isempty(t)
            fprintf('   [%g .. %g]', t(1), t(end));
        end
        fprintf('\n');
    else
        fprintf('  TIME : %s\n', class(t));
    end

    if isempty(d)
        fprintf(['  *** EMPTY. The call succeeded and returned nothing, ' ...
                 'which is the\n      silent-failure shape: check the ' ...
                 'epochprobemap line above.\n']);
    else
        fprintf('  first sample(s): %s\n', ...
            mat2str(d(1:min(4, size(d,1)), 1:min(4, size(d,2))), 4));
    end
end

fprintf('\n=== done ===\n\n');
end

% ===================== helpers ==============================================

function p = localExpandTilde(p)
%LOCALEXPANDTILDE Resolve a leading `~`; MATLAB's file functions do not.
p = char(p);
if isempty(p) || p(1) ~= '~'
    return;
end
if numel(p) > 1 && p(2) ~= filesep && p(2) ~= '/'
    return;
end
home = getenv('HOME');
if isempty(home)
    home = getenv('USERPROFILE');
end
if isempty(home)
    return;
end
rest = p(2:end);
while ~isempty(rest) && (rest(1) == filesep || rest(1) == '/')
    rest(1) = [];
end
p = fullfile(home, rest);
end

function s = localShort(x)
if isempty(x); s = '<none>'; return; end
x = char(x);
if numel(x) > 12; s = [x(1:12) '...']; else; s = x; end
end
