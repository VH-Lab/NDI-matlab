function curate(S, probe, options)
% NDI.FUN.PROBE.IMPORT.JRCLUST.CURATE - open JRCLUST's curation GUI for a probe's sort
%
% NDI.FUN.PROBE.IMPORT.JRCLUST.CURATE(S, PROBE, ...)
%
% Opens JRCLUST's interactive curation interface for the sorted units of the
% ndi.probe (or ndi.element) PROBE of the ndi.session S - the equivalent of
%
%       jrc manual [S.path]/.JRCLUST/[element string]/jrclust.prm
%
% Use it to merge, split and delete units and, importantly, to ANNOTATE each unit
% ('single', 'multi', 'noise', ...). NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE imports the
% units by their annotation, so units that are not annotated are not imported. Save
% the clustering before closing the curator; that writes the annotations into
% JRCLUST's results file.
%
% The spikes must have been sorted first (NDI.FUN.PROBE.IMPORT.JRCLUST.RUN).
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | jrclustDir ('.JRCLUST')  | Directory (within S.path) holding the JRCLUST work. |
% | prmName ('jrclust.prm')  | Name of the JRCLUST parameter file.                 |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.JRCLUST.RUN, NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE,
%   NDI.FUN.PROBE.IMPORT.JRCLUST.TRACES
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    ndi.fun.probe.import.jrclust.curate(S, p{1});
%

    arguments
        S
        probe
        options.jrclustDir (1,:) char = '.JRCLUST'
        options.prmName (1,:) char = 'jrclust.prm'
    end

    prmFile = ndi.fun.probe.import.jrclust.requireprm(S, probe, ...
        'jrclustDir', options.jrclustDir, 'prmName', options.prmName);

    st = ndi.fun.probe.import.jrclust.status(S, probe, ...
        'jrclustDir', options.jrclustDir, 'prmName', options.prmName, ...
        'checkDatabase', false);
    if ~st.sorted,
        error('ndi:fun:probe:import:jrclust:curate:notSorted', ...
            ['The spikes of probe %s have not been sorted yet. Run ' ...
            'ndi.fun.probe.import.jrclust.run(S, probe) first.'], probe.elementstring());
    end;

    try
        jrc('manual', prmFile);
    catch ME
        error('ndi:fun:probe:import:jrclust:curate:failed', ...
            'JRCLUST ''manual'' failed for %s: %s', prmFile, ME.message);
    end;

end % curate()
