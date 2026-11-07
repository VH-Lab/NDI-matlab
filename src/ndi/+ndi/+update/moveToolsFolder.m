function result = moveToolsFolder(newFolder, options)
% MOVETOOLSFOLDER - move NDI-matlab and the tools ndi_install installed to another folder
%
%   RESULT = ndi.update.moveToolsFolder(NEWFOLDER)
%
%   Moves the tools folder (see ndi.update.toolsFolder), which holds
%   NDI-matlab and every other repository ndi_install put next to it, to
%   NEWFOLDER, and points MATLAB at the new place. By default the tools
%   folder is [userpath filesep 'tools'], inside Documents/MATLAB.
%
%   NEWFOLDER must be a full path (not starting with '~'). It must not
%   exist yet, or be an empty folder, and it must not be inside the
%   current tools folder. Everything in the current tools folder goes
%   into NEWFOLDER itself, so NEWFOLDER/NDI-matlab is the new NDI-matlab.
%
%   The steps, in order:
%     1. Check everything that can be checked first: NEWFOLDER, and that
%        startup.m (in your userpath) runs vhtools_startup from the
%        current tools folder. If anything is wrong, nothing is changed.
%     2. Copy the whole tools folder to NEWFOLDER, and check that every
%        file arrived. If the copy fails, the partial copy is removed and
%        nothing else is changed.
%     3. Rewrite the vhtools_startup line in startup.m so it points to
%        NEWFOLDER. The previous startup.m is kept beside it as
%        startup.m.bak.
%     4. Replace the old folder with the new one on the current MATLAB
%        path, so NDI keeps working in this session.
%     5. Delete the old tools folder. If that fails (on Windows a file
%        that MATLAB has open cannot be deleted), a warning says so;
%        delete it yourself after restarting MATLAB.
%
%   Restart MATLAB afterwards, so that everything is loaded from the new
%   folder.
%
%   Later updates (ndi.update.install, the navigator's Update button, and
%   ndi_install with no input) use the folder that holds NDI-matlab, so
%   they keep using NEWFOLDER.
%
%   RESULT is a structure with fields:
%       Moved          - true if the tools were moved; false if you
%                        answered No when asked
%       From           - the old tools folder
%       To             - the new tools folder
%       StartupFile    - the startup.m that was changed
%       StartupBackup  - the copy of the previous startup.m
%       OldDeleted     - true if the old tools folder was deleted
%
%   Optional Name-Value Arguments:
%     Confirm     - describe what will happen and ask before doing it
%                   (default true). The preferences editor asks in its
%                   own window and passes false.
%     DeleteOld   - delete the old tools folder at the end (default true)
%     UpdatePath  - change the current MATLAB path (default true)
%     From        - the tools folder to move (default
%                   ndi.update.toolsFolder()). For tests.
%     StartupFile - the startup.m to rewrite (default
%                   fullfile(userpath, 'startup.m')). For tests.
%
%   Errors (identifiers start with 'ndi:update:moveToolsFolder:'):
%     notGit, noFolder, relativePath, sameFolder, insideOld, notEmpty,
%     noStartupFile, noStartupLine, copyFailed, startupWriteFailed
%
%   Example:
%       ndi.update.moveToolsFolder('/Users/me/code/ndi-tools')
%
%   In the preferences editor (ndi.gui.preferencesEditor, or Prefs in the
%   navigator), the "Tools folder..." button does the same.
%
%   See also: ndi.update.toolsFolder, ndi_install, ndi.gui.preferencesEditor

    arguments
        newFolder (1,1) string {mustBeNonzeroLengthText}
        options.Confirm (1,1) logical = true
        options.DeleteOld (1,1) logical = true
        options.UpdatePath (1,1) logical = true
        options.From (1,1) string = ""
        options.StartupFile (1,1) string = ""
    end

    % ---- 1. checks; nothing is changed until all of them pass ----

    from = options.From;
    if strlength(from) == 0
        from = ndi.update.toolsFolder();
        if strlength(from) == 0
            error('ndi:update:moveToolsFolder:notGit', ...
                ['NDI-matlab is not a git clone made by ndi_install (it may be ' ...
                 'installed as a toolbox), so there is no tools folder to move.']);
        end
    end
    if ~isfolder(from)
        error('ndi:update:moveToolsFolder:noFolder', ...
            'The tools folder %s does not exist.', from);
    end
    fromNames = unique([stripSep(from), canonicalPath(from)], 'stable');
    from = canonicalPath(from);

    newFolder = strip(newFolder);
    if startsWith(newFolder, "~") || ~isAbsolutePath(newFolder)
        error('ndi:update:moveToolsFolder:relativePath', ...
            ['Give the full path of the new folder, such as /Users/me/ndi-tools ' ...
             'or C:\\ndi-tools (not %s).'], newFolder);
    end
    to = canonicalPath(newFolder);

    if samePath(to, from)
        error('ndi:update:moveToolsFolder:sameFolder', ...
            'The tools are already in %s.', from);
    end
    if isInside(to, from)
        error('ndi:update:moveToolsFolder:insideOld', ...
            'The new folder %s is inside the current tools folder %s.', to, from);
    end
    if isfile(to) || (isfolder(to) && ~isEmptyFolder(to))
        error('ndi:update:moveToolsFolder:notEmpty', ...
            ['%s already exists and is not an empty folder. Choose a new ' ...
             'folder, or an empty one.'], to);
    end

    startupFile = options.StartupFile;
    if strlength(startupFile) == 0
        if isempty(userpath)
            error('ndi:update:moveToolsFolder:noStartupFile', ...
                'Your MATLAB userpath is empty, so there is no startup.m to update.');
        end
        startupFile = string(fullfile(userpath, 'startup.m'));
    end
    if ~isfile(startupFile)
        error('ndi:update:moveToolsFolder:noStartupFile', ...
            ['%s does not exist, so MATLAB does not load the tools from it. ' ...
             'Move the tools yourself, or run ndi_install first.'], startupFile);
    end
    oldText = string(fileread(startupFile));
    [newText, nChanged] = rewriteStartup(oldText, fromNames, to);
    if nChanged == 0
        error('ndi:update:moveToolsFolder:noStartupLine', ...
            ['%s has no vhtools_startup line that runs the tools from %s, ' ...
             'so the tools cannot be moved automatically. Move the folder ' ...
             'yourself and edit startup.m to match.'], startupFile, from);
    end

    result = struct('Moved', false, 'From', from, 'To', to, ...
        'StartupFile', startupFile, 'StartupBackup', startupFile + ".bak", ...
        'OldDeleted', false);

    if options.Confirm
        fprintf('This will move the NDI tools folder\n');
        fprintf('    from %s\n', from);
        fprintf('    to   %s\n', to);
        fprintf('It copies the folder, checks the copy, points startup.m\n');
        fprintf('(%s) to the new folder,\n', startupFile);
        if options.DeleteOld
            fprintf('and deletes the old folder. Restart MATLAB afterwards.\n');
        else
            fprintf('and leaves the old folder in place. Restart MATLAB afterwards.\n');
        end
        reply = input('Move the tools folder? Y/N [N]: ', 's');
        if ~strcmpi(strtrim(reply), 'y')
            disp('Nothing was changed.');
            return
        end
    end

    % ---- 2. copy, and check the copy ----

    createdTo = ~isfolder(to);
    if createdTo
        [ok, msg] = mkdir(to);
        if ~ok
            error('ndi:update:moveToolsFolder:copyFailed', ...
                'Could not create %s: %s', to, msg);
        end
    end

    fprintf('Copying %s to %s...\n', from, to);
    entries = dir(from);
    entries = entries(~ismember({entries.name}, {'.', '..'}));
    try
        for k = 1:numel(entries)
            src = fullfile(from, entries(k).name);
            dst = fullfile(to, entries(k).name);
            [ok, msg] = copyfile(src, dst, 'f');
            if ~ok
                error('ndi:update:moveToolsFolder:copyFailed', ...
                    'Could not copy %s to %s: %s', src, dst, msg);
            end
        end
        nFrom = countFiles(from);
        nTo = countFiles(to);
        if nTo < nFrom
            error('ndi:update:moveToolsFolder:copyFailed', ...
                'Only %d of the %d files in %s were copied to %s.', ...
                nTo, nFrom, from, to);
        end
    catch ME
        removeCopy(to, createdTo);
        if strcmp(ME.identifier, 'ndi:update:moveToolsFolder:copyFailed')
            msg = ME.message;
        else
            msg = sprintf('Copying %s to %s failed: %s', from, to, ME.message);
        end
        error('ndi:update:moveToolsFolder:copyFailed', ...
            '%s\nNothing was changed; the partial copy was removed.', msg);
    end

    % ---- 3. startup.m ----

    [ok, msg] = copyfile(startupFile, result.StartupBackup, 'f');
    if ~ok
        removeCopy(to, createdTo);
        error('ndi:update:moveToolsFolder:startupWriteFailed', ...
            ['Could not back up %s: %s\nNothing was changed; the copy in %s ' ...
             'was removed.'], startupFile, msg, to);
    end
    fid = fopen(startupFile, 'w', 'n', 'UTF-8');
    if fid < 0
        removeCopy(to, createdTo);
        error('ndi:update:moveToolsFolder:startupWriteFailed', ...
            'Could not write %s. Nothing was changed; the copy in %s was removed.', ...
            startupFile, to);
    end
    fprintf(fid, '%s', newText);
    fclose(fid);
    fprintf('Updated %s (the previous version is %s).\n', ...
        startupFile, result.StartupBackup);
    result.Moved = true;

    % ---- 4. this session's path ----

    if options.UpdatePath
        entriesOnPath = string(strsplit(path, pathsep));
        path(char(strjoin(relocate(entriesOnPath, fromNames, to), pathsep)));
        here = string(pwd);
        moved = relocate(here, fromNames, to);
        if moved ~= here && isfolder(moved)
            cd(moved);
        end
    end

    % ---- 5. the old folder ----

    if options.DeleteOld
        [ok, msg] = rmdir(from, 's');
        result.OldDeleted = ok;
        if ok
            fprintf('Deleted %s.\n', from);
        else
            warning('ndi:update:moveToolsFolder:oldNotDeleted', ...
                ['The tools were moved to %s, but the old folder %s could not ' ...
                 'be deleted completely (%s). Delete it yourself after ' ...
                 'restarting MATLAB.'], to, from, msg);
        end
    end

    fprintf('The NDI tools are now in %s. Please restart MATLAB.\n', to);
end


function [text, nChanged] = rewriteStartup(text, fromNames, to)
% Point the vhtools_startup line(s) of startup.m from any of FROMNAMES to TO.
% The folder appears inside a single-quoted MATLAB char, so apostrophes in
% it are doubled there. Only lines that mention vhtools_startup change.
    if contains(text, sprintf('\r\n'))
        eol = sprintf('\r\n');
    else
        eol = newline;
    end
    lines = split(text, eol);
    toQuoted = strrep(to, "'", "''");
    nChanged = 0;
    for i = 1:numel(lines)
        if ~contains(lines(i), "vhtools_startup")
            continue
        end
        for f = 1:numel(fromNames)
            [lines(i), n] = replaceFolder(lines(i), strrep(fromNames(f), "'", "''"), toQuoted);
            if n > 0
                nChanged = nChanged + 1;
                break
            end
        end
    end
    text = join(lines, eol);
end


function [s, n] = replaceFolder(s, oldFolder, newFolder)
% Replace OLDFOLDER in S with NEWFOLDER where it is a whole folder: followed
% by a file separator, a quote, or the end. / and \ are interchangeable,
% and on Windows case does not matter.
    pattern = regexptranslate('escape', char(oldFolder));
    pattern = regexprep(pattern, '(\\\\|/)', '[\\\\/]');
    pattern = [pattern '(?=[\\/''"]|$)'];
    replacement = regexprep(char(newFolder), '([\\$])', '\\$1');
    caseOpt = {};
    if ispc
        caseOpt = {'ignorecase'};
    end
    n = numel(regexp(char(s), pattern, 'start', caseOpt{:}));
    if n > 0
        s = string(regexprep(char(s), pattern, replacement, caseOpt{:}));
    end
end


function entries = relocate(entries, fromNames, to)
% Change each entry that is one of FROMNAMES, or inside one, to the same
% place under TO.
    for i = 1:numel(entries)
        for f = 1:numel(fromNames)
            if samePath(entries(i), fromNames(f))
                entries(i) = to;
                break
            elseif isInside(entries(i), fromNames(f))
                entries(i) = to + extractAfter(entries(i), strlength(stripSep(fromNames(f))));
                break
            end
        end
    end
end


function p = canonicalPath(p)
% The absolute path with '.', '..' and symbolic links resolved, without a
% trailing separator. Works for a folder that does not exist yet.
    try
        p = string(java.io.File(char(p)).getCanonicalPath());
    catch
        % no Java: keep the path as given
    end
    p = stripSep(p);
end


function p = stripSep(p)
    p = string(p);
    while strlength(p) > 1 && (endsWith(p, "/") || endsWith(p, "\")) ...
            && ~(ispc && strlength(p) == 3 && extractBetween(p, 2, 2) == ":")
        p = extractBefore(p, strlength(p));
    end
end


function tf = isAbsolutePath(p)
    if ispc
        tf = ~isempty(regexp(char(p), '^([A-Za-z]:[\\/]|\\\\)', 'once'));
    else
        tf = startsWith(p, "/");
    end
end


function tf = samePath(a, b)
    a = stripSep(a);
    b = stripSep(b);
    if ispc
        tf = strcmpi(strrep(a, "/", "\"), strrep(b, "/", "\"));
    else
        tf = a == b;
    end
end


function tf = isInside(child, parent)
% True if CHILD is strictly inside PARENT.
    child = stripSep(child);
    parent = stripSep(parent);
    if ispc
        child = lower(strrep(child, "/", "\"));
        parent = lower(strrep(parent, "/", "\"));
        sep = "\";
    else
        sep = "/";
    end
    if endsWith(parent, sep)
        prefix = parent;
    else
        prefix = parent + sep;
    end
    tf = startsWith(child, prefix);
end


function tf = isEmptyFolder(folder)
    d = dir(folder);
    tf = all(ismember({d.name}, {'.', '..'}));
end


function n = countFiles(folder)
    d = dir(fullfile(folder, '**', '*'));
    n = sum(~[d.isdir]);
end


function removeCopy(to, createdTo)
% Remove what this function copied into TO. TO was new, or empty, before.
% Never raises: it runs while another error is being reported.
    if ~isfolder(to)
        return
    end
    if createdTo
        [~, ~] = rmdir(to, 's');
    else
        d = dir(to);
        d = d(~ismember({d.name}, {'.', '..'}));
        for k = 1:numel(d)
            item = fullfile(to, d(k).name);
            if d(k).isdir
                [~, ~] = rmdir(item, 's');
            else
                try
                    delete(item);
                catch
                end
            end
        end
    end
end
