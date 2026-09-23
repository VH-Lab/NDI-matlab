function traces(S, probe, options)
% NDI.FUN.PROBE.IMPORT.JRCLUST.TRACES - view a probe's raw traces in JRCLUST
%
% NDI.FUN.PROBE.IMPORT.JRCLUST.TRACES(S, PROBE, ...)
%
% Opens JRCLUST's trace viewer on the data of the ndi.probe (or ndi.element) PROBE
% of the ndi.session S - the equivalent of
%
%       jrc traces [S.path]/.JRCLUST/[element string]/jrclust.prm
%
% This is the quickest way to confirm that the channels, filtering and site map in
% the parameter file are right before spending time on detection and sorting.
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | jrclustDir ('.JRCLUST')  | Directory (within S.path) holding the JRCLUST work. |
% | prmName ('jrclust.prm')  | Name of the JRCLUST parameter file.                 |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.EXPORT.JRCLUST, NDI.FUN.PROBE.IMPORT.JRCLUST.RUN,
%   NDI.FUN.PROBE.IMPORT.JRCLUST.CURATE
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    ndi.fun.probe.import.jrclust.traces(S, p{1});
%

    arguments
        S
        probe
        options.jrclustDir (1,:) char = '.JRCLUST'
        options.prmName (1,:) char = 'jrclust.prm'
    end

    prmFile = ndi.fun.probe.import.jrclust.requireprm(S, probe, ...
        'jrclustDir', options.jrclustDir, 'prmName', options.prmName);

    try
        jrc('traces', prmFile);
    catch ME
        error('ndi:fun:probe:import:jrclust:traces:failed', ...
            'JRCLUST ''traces'' failed for %s: %s', prmFile, ME.message);
    end;

end % traces()
