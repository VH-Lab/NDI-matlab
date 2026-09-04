function p = paths(S, probe, options)
% NDI.FUN.PROBE.IMPORT.JRCLUST.PATHS - standard JRCLUST file locations for an NDI probe
%
% P = NDI.FUN.PROBE.IMPORT.JRCLUST.PATHS(S, PROBE, ...)
%
% Returns a struct P with the file locations that the NDI/JRCLUST pipeline uses for
% the ndi.probe (or ndi.element) PROBE of the ndi.session S. Every function in the
% NDI.FUN.PROBE.IMPORT.JRCLUST package (and NDI.FUN.PROBE.EXPORT.JRCLUST) goes
% through this function, so the layout is defined in exactly one place. It matches
% the layout JRCLUST's own jrc('bootstrap','ndi',...) uses:
%
%   [S.path]/.JRCLUST/[element string]/jrclust.prm       the parameter file
%   [S.path]/.JRCLUST/[element string]/jrclust_res.mat   JRCLUST's results file
%
% where [element string] is PROBE.elementstring() with spaces replaced by
% underscores (e.g. 'Rightcortex_|_1').
%
% Fields of P:
%   elementString - the probe's element string, spaces replaced by underscores
%   directory     - the JRCLUST working directory for this probe
%   prmFile       - the full path to the JRCLUST parameter (.prm) file
%   sessionName   - JRCLUST's "session name" (the .prm file name without extension)
%   resFile       - the full path to JRCLUST's results file ([sessionName]_res.mat)
%
% The files need not exist; use NDI.FUN.PROBE.IMPORT.JRCLUST.STATUS to find out
% which stages of the pipeline have been run.
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | jrclustDir ('.JRCLUST')  | Directory (within S.path) holding the JRCLUST work. |
% | prmName ('jrclust.prm')  | Name of the JRCLUST parameter file.                 |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.EXPORT.JRCLUST, NDI.FUN.PROBE.IMPORT.JRCLUST.STATUS,
%   NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    P = ndi.fun.probe.import.jrclust.paths(S, p{1});
%    edit(P.prmFile);
%
% Fields: elementString, directory, sessionName, prmFile, resFile, and JRCLUST's
% intermediate files rawFile, filtFile, featuresFile and histFile.
%

    arguments
        S
        probe
        options.jrclustDir (1,:) char = '.JRCLUST'
        options.prmName (1,:) char = 'jrclust.prm'
    end

    elementString = probe.elementstring();
    elementString(elementString==' ') = '_';

    [~,sessionName,~] = fileparts(options.prmName);

    p = struct();
    p.elementString = elementString;
    p.directory     = fullfile(S.path, options.jrclustDir, elementString);
    p.prmFile       = fullfile(p.directory, options.prmName);
    p.sessionName   = sessionName;
    p.resFile       = fullfile(p.directory, [sessionName '_res.mat']);
    % JRCLUST's intermediate files (jrclust.Config: rawFile / filtFile /
    % featuresFile / histFile). Detection writes the first three; sorting reads the
    % features (jrclust.sort.SortController errors 'cannot sort without features'
    % when they are missing), and the curator appends to the history file.
    p.rawFile       = fullfile(p.directory, [sessionName '_raw.jrc']);
    p.filtFile      = fullfile(p.directory, [sessionName '_filt.jrc']);
    p.featuresFile  = fullfile(p.directory, [sessionName '_features.jrc']);
    p.histFile      = fullfile(p.directory, [sessionName '_hist.jrc']);

end
