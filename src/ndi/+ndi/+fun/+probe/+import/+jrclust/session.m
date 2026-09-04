function session(S, options)
% NDI.FUN.PROBE.IMPORT.JRCLUST.SESSION - import JRCLUST results for all probes in a session
%
% NDI.FUN.PROBE.IMPORT.JRCLUST.SESSION(S, ...)
%
% For each probe of the given type (by default 'n-trode') in the ndi.session S, imports
% the JRCLUST spike sorting results by calling NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE.
% Probes that have no JRCLUST results are skipped with a warning.
%
% This function takes the same name/value pairs as NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE,
% plus 'type':
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | type ('n-trode')         | Probe type to look for. '' means every probe.       |
% | jrclustDir ('.JRCLUST')  | Directory (within S.path) holding the JRCLUST work. |
% | prmName ('jrclust.prm')  | Name of the JRCLUST parameter file.                 |
% | qualityLabels            | String array of curation notes to import.           |
% |   (["single","multi"])   |                                                     |
% | qualityValues ([1 4])    | quality_number assigned to each label (parallel).   |
% | checkElement (true)      | Verify the parameter file matches each probe.       |
% | force (0)                | Re-import even if the checksum is unchanged.        |
% | dryRun (false)           | Report what would be imported without changing the  |
% |                          |   database.                                         |
% | verbose (1)              | 0/1 Should we be verbose?                           |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE, NDI.FUN.PROBE.EXPORT.JRCLUST
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    ndi.fun.probe.import.jrclust.session(S);
%

    arguments
        S
        options.type (1,:) char = 'n-trode'
        options.jrclustDir (1,:) char = '.JRCLUST'
        options.prmName (1,:) char = 'jrclust.prm'
        options.qualityLabels (1,:) string = ["single","multi"]
        options.qualityValues (1,:) double = [1 4]
        options.checkElement (1,1) logical = true
        options.force (1,1) double = 0
        options.dryRun (1,1) logical = false
        options.verbose (1,1) double = 1
    end

    verbose = options.verbose;

    if isempty(options.type),
        probeList = S.getprobes();
    else,
        probeList = S.getprobes('type', options.type);
    end;
    if verbose,
        disp(['Found ' int2str(numel(probeList)) ' probe(s) in ' S.reference '.']);
    end;

    for p=1:numel(probeList),
        st = ndi.fun.probe.import.jrclust.status(S, probeList{p}, ...
            'jrclustDir', options.jrclustDir, 'prmName', options.prmName, ...
            'checkDatabase', false);
        if ~st.sorted,
            warning(['Skipping probe ' probeList{p}.elementstring() ': no JRCLUST sort ' ...
                'found at ' st.resFile '.']);
            continue;
        end;
        ndi.fun.probe.import.jrclust.probe(S, probeList{p}, ...
            'jrclustDir', options.jrclustDir, ...
            'prmName', options.prmName, ...
            'qualityLabels', options.qualityLabels, ...
            'qualityValues', options.qualityValues, ...
            'checkElement', options.checkElement, ...
            'force', options.force, ...
            'dryRun', options.dryRun, ...
            'verbose', options.verbose);
    end;

    if verbose,
        disp(['Done importing JRCLUST results for ' S.reference '.']);
    end;

end % session()
