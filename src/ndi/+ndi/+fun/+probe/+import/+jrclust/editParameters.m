function prmFile = editParameters(S, probe, options)
% NDI.FUN.PROBE.IMPORT.JRCLUST.EDITPARAMETERS - open a probe's JRCLUST parameter file for editing
%
% PRMFILE = NDI.FUN.PROBE.IMPORT.JRCLUST.EDITPARAMETERS(S, PROBE, ...)
%
% Opens the JRCLUST parameter (.prm) file of the ndi.probe (or ndi.element) PROBE of
% the ndi.session S in the MATLAB editor, and returns its path. The file is written
% by NDI.FUN.PROBE.EXPORT.JRCLUST; editing it by hand is the normal way to set the
% sorting parameters. The ones most often changed are:
%
%   useGPU        - 0 unless you have a supported GPU
%   maxSecLoad    - seconds of data loaded at a time; lower it if memory is tight
%   siteLoc       - the site locations, in microns (x in column 1, y in column 2)
%   siteMap       - the map of site id to recording channel
%   shankMap      - the shank each site belongs to
%   ignoreChans   - channels to leave out (e.g. dead channels)
%   evtGroupRad   - maximum distance (microns) over which sites are grouped for
%                     spike extraction; use a large value (e.g. 800) to group all
%                     the sites of a tetrode-like probe
%   nSiteDir      - leave empty to group sites by evtGroupRad
%
% Save the file in the editor before running detection or sorting.
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | jrclustDir ('.JRCLUST')  | Directory (within S.path) holding the JRCLUST work. |
% | prmName ('jrclust.prm')  | Name of the JRCLUST parameter file.                 |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.EXPORT.JRCLUST, NDI.FUN.PROBE.IMPORT.JRCLUST.RUN
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    ndi.fun.probe.import.jrclust.editParameters(S, p{1});
%

    arguments
        S
        probe
        options.jrclustDir (1,:) char = '.JRCLUST'
        options.prmName (1,:) char = 'jrclust.prm'
    end

    P = ndi.fun.probe.import.jrclust.paths(S, probe, ...
        'jrclustDir', options.jrclustDir, 'prmName', options.prmName);
    prmFile = P.prmFile;

    if ~isfile(prmFile),
        error('ndi:fun:probe:import:jrclust:noPrmFile', ...
            ['No JRCLUST parameter file at %s. Create one first with ' ...
            'ndi.fun.probe.export.jrclust(S, probe).'], prmFile);
    end;

    edit(prmFile);

end % editParameters()
