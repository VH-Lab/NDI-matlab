function cmd = viewCommand(launcher, sessionPath, pyramidID, options)
% NDI.FUN.DOC.LIGHTSHEET.VIEWCOMMAND - the command line that opens a pyramid in napari
%
%   CMD = NDI.FUN.DOC.LIGHTSHEET.VIEWCOMMAND(LAUNCHER, SESSIONPATH, PYRAMIDID)
%   returns the shell command, as a char row vector, that hands this
%   lightsheetZarrPyramid to the napari viewer in NDI-python.
%
%   PURE, AND THAT IS THE POINT. Nothing here launches anything or
%   touches the filesystem, so the command can be built, shown to the
%   user in a dialog, and asserted in a test with no display and no
%   Python. When the launch then fails, the exact command is on screen
%   to be copied into a terminal, which is the difference between a bug
%   report and a shrug.
%
%   THE PYRAMID IS ALWAYS NAMED. The viewer will refuse to open a
%   session that holds more than one lightsheetZarrPyramid without being
%   told which one, so this function refuses to build a command without
%   PYRAMIDID.
%
%   Optional Name-Value Arguments:
%     channel (-1)     - 1-based channel index to display. -1 opens all
%                        channels as separate napari layers.
%     reduction ('')   - request an alternate reduction: '' opens the
%                        pyramid the user picked; 'mean' or 'max'
%                        instructs the viewer to look for a sibling
%                        pyramid with that reduction and open that one
%                        instead. Empty leaves the choice to what the
%                        pyramid id names.
%     controls (true)  - dock the reduction / channel / level panels
%     name ('')        - image layer name. '' leaves the viewer to use
%                        the pyramid's own label.
%     level (-1)       - initial level to display. -1 lets the viewer
%                        pick based on the window size (levelTable is
%                        cheap; picking is not expensive).
%
%   See also: ndi.gui.app.LightsheetZarrManager,
%             ndi.fun.doc.lightsheet.chooseLevel

    arguments
        launcher char
        sessionPath char
        pyramidID char
        options.channel (1,1) double {mustBeInteger} = -1
        options.reduction char {mustBeMember(options.reduction, {'', 'mean', 'max'})} = ''
        options.controls (1,1) logical = true
        options.name char = ''
        options.level (1,1) double {mustBeInteger} = -1
    end

    if isempty(strtrim(launcher))
        error('NDI:lightsheet:viewCommand:noLauncher', ...
            ['No viewer launcher is set. It is normally ' ...
             '/usr/local/bin/napariViewLightsheet, a shell wrapper ' ...
             'that scrubs MATLAB''s library paths before starting ' ...
             'Python.']);
    end
    if isempty(strtrim(sessionPath))
        error('NDI:lightsheet:viewCommand:noSessionPath', ...
            ['This session has no directory on disk, so there is ' ...
             'nothing for the viewer to open. The napari viewer ' ...
             'reads an ndi.session.dir.']);
    end
    if isempty(strtrim(pyramidID))
        error('NDI:lightsheet:viewCommand:noPyramidID', ...
            ['viewCommand refuses to build a command without a ' ...
             'lightsheetZarrPyramid id; the viewer will not guess ' ...
             'which pyramid to open when a session holds more than ' ...
             'one.']);
    end

    parts = { ...
        shellQuote(strtrim(launcher)), ...
        shellQuote(sessionPath), ...
        '--pyramid', shellQuote(pyramidID)};
    if ~isempty(options.reduction)
        parts{end+1} = '--reduction';
        parts{end+1} = shellQuote(options.reduction);
    end
    if options.channel >= 1
        parts{end+1} = '--channel';
        parts{end+1} = sprintf('%d', options.channel);
    end
    if options.level >= 0
        parts{end+1} = '--level';
        parts{end+1} = sprintf('%d', options.level);
    end
    if ~options.controls
        parts{end+1} = '--no-controls';
    end
    if ~isempty(strtrim(options.name))
        parts{end+1} = '--name';
        parts{end+1} = shellQuote(strtrim(options.name));
    end
    cmd = strjoin(parts, ' ');
end

function s = shellQuote(str)
    str = char(str);
    if ispc
        s = ['"' strrep(str, '"', '""') '"'];
    else
        s = ['''' strrep(str, '''', '''\''''') ''''];
    end
end
