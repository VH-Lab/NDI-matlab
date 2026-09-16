function prmFile = requireprm(S, probe, options)
% NDI.FUN.PROBE.IMPORT.JRCLUST.REQUIREPRM - check that JRCLUST and a probe's parameter file are ready
%
% PRMFILE = NDI.FUN.PROBE.IMPORT.JRCLUST.REQUIREPRM(S, PROBE, ...)
%
% Returns the path to the JRCLUST parameter file for the probe PROBE of the
% ndi.session S, after checking that
%   1) JRCLUST, with its NDI support, is installed (NDI.FUN.PROBE.IMPORT.JRCLUST.INSTALL), and
%   2) the parameter file exists.
%
% Errors with an explanatory message if either check fails. This is the common
% precondition of the functions that hand work to JRCLUST
% (NDI.FUN.PROBE.IMPORT.JRCLUST.RUN, .CURATE and .TRACES).
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | jrclustDir ('.JRCLUST')  | Directory (within S.path) holding the JRCLUST work. |
% | prmName ('jrclust.prm')  | Name of the JRCLUST parameter file.                 |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.JRCLUST.INSTALL, NDI.FUN.PROBE.EXPORT.JRCLUST
%

    arguments
        S
        probe
        options.jrclustDir (1,:) char = '.JRCLUST'
        options.prmName (1,:) char = 'jrclust.prm'
    end

    info = ndi.fun.probe.import.jrclust.install();
    if ~info.ok,
        error('ndi:fun:probe:import:jrclust:notInstalled', '%s', info.summary);
    end;

    P = ndi.fun.probe.import.jrclust.paths(S, probe, ...
        'jrclustDir', options.jrclustDir, 'prmName', options.prmName);
    prmFile = P.prmFile;

    if ~isfile(prmFile),
        error('ndi:fun:probe:import:jrclust:noPrmFile', ...
            ['No JRCLUST parameter file at %s. Create one first with ' ...
            'ndi.fun.probe.export.jrclust(S, probe).'], prmFile);
    end;

end % requireprm()
