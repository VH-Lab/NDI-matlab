function view(session, pyramidID, options)
% NDI.FUN.DOC.LIGHTSHEET.VIEW - launch the napari viewer on a lightsheet pyramid
%
%   ndi.fun.doc.lightsheet.VIEW(SESSION)
%   ndi.fun.doc.lightsheet.VIEW(SESSION, PYRAMIDID)
%   ndi.fun.doc.lightsheet.VIEW(..., 'launcher', '/path/to/napariViewLightsheet')
%
%   Builds the napariViewLightsheet command line (via
%   ndi.fun.doc.lightsheet.VIEWCOMMAND) and dispatches it through SYSTEM.
%   The launcher path defaults to /usr/local/bin/napariViewLightsheet,
%   the shell wrapper installed alongside NDI-python.
%
%   PYRAMIDID is optional. When omitted, the launcher runs in --list
%   mode: it enumerates every lightsheetZarrPyramid in the session and
%   prints their ids on stdout so the caller can pick one for a second
%   call. When PYRAMIDID is passed, the pyramid is opened in napari.
%
%   Optional Name-Value Arguments:
%     launcher    - char, path to the shell wrapper. Default
%                   /usr/local/bin/napariViewLightsheet.
%     sessionPath - char, override the session directory used for the
%                   viewer's --session argument. Default: session.path().
%     reduction   - char, '' | 'mean' | 'max'. Passed through to
%                   viewCommand; empty leaves the choice to what the
%                   pyramid id names.
%     channel     - 1-based channel index, or -1 for all channels.
%                   Passed through to viewCommand.
%     level       - initial level; -1 lets the viewer choose.
%     controls    - dock the reduction / channel / level control panels
%                   (default true).
%     name        - napari layer name; empty uses the pyramid's own
%                   label.
%     wait        - block until the viewer exits (default false so
%                   MATLAB stays interactive; the command is
%                   backgrounded on POSIX shells).
%     verbose     - print the command before running it (default true).
%
%   Example -- list, then open:
%     ndi.fun.doc.lightsheet.view(S);              % prints ids
%     ndi.fun.doc.lightsheet.view(S, '<paste-id>');
%
%   See also: ndi.fun.doc.lightsheet.viewCommand,
%             ndi.gui.app.LightsheetZarrManager

    arguments
        session (1,1)
        pyramidID char = ''
        options.launcher (1,:) char = '/usr/local/bin/napariViewLightsheet'
        options.sessionPath (1,:) char = ''
        options.reduction (1,:) char {mustBeMember(options.reduction, {'', 'mean', 'max'})} = ''
        options.channel (1,1) double {mustBeInteger} = -1
        options.level (1,1) double {mustBeInteger} = -1
        options.controls (1,1) logical = true
        options.name (1,:) char = ''
        options.wait (1,1) logical = false
        options.verbose (1,1) logical = true
    end

    sessionPath = options.sessionPath;
    if isempty(sessionPath)
        try
            sessionPath = char(session.path());
        catch
            error('NDI:lightsheet:view:noSessionPath', ...
                ['Could not read a directory from the session; pass ' ...
                 '''sessionPath'' explicitly.']);
        end
    end

    if isempty(pyramidID)
        cmd = sprintf('%s %s --list', shq(options.launcher), shq(sessionPath));
    else
        cmd = ndi.fun.doc.lightsheet.viewCommand(options.launcher, ...
            sessionPath, pyramidID, ...
            'channel',   options.channel, ...
            'reduction', options.reduction, ...
            'controls',  options.controls, ...
            'name',      options.name, ...
            'level',     options.level);
    end

    if ~options.wait && ispc == 0 %#ok<ISPC>
        % Background the process on POSIX so MATLAB does not block.
        % On Windows use `start` (kept simple: fall back to a
        % foreground wait).
        cmd = [cmd ' &'];
    end

    if options.verbose
        fprintf('Executing: %s\n', cmd);
    end
    status = system(cmd);
    if status ~= 0 && options.wait
        warning('NDI:lightsheet:view:nonZeroExit', ...
            'Launcher returned status %d.', status);
    end
end

function s = shq(s)
% Minimal POSIX shell quoting: wrap in single quotes and escape any
% single quote inside. Enough for paths and identifiers; not a general
% shell escaper.
    s = ['''' strrep(s, '''', '''\''''') ''''];
end
