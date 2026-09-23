function s = status(S, probe, options)
% NDI.FUN.PROBE.IMPORT.JRCLUST.STATUS - JRCLUST pipeline status for a probe
%
% S_STATUS = NDI.FUN.PROBE.IMPORT.JRCLUST.STATUS(S, PROBE, ...)
%
% Reports where PROBE stands in the NDI/JRCLUST pipeline for the ndi.session S, by
% checking the files each step produces and (optionally) the NDI database. Returns a
% struct with the fields:
%
%   directory    - the probe's JRCLUST directory (see NDI.FUN.PROBE.IMPORT.JRCLUST.PATHS)
%   prmFile      - the JRCLUST parameter file
%   resFile      - the JRCLUST results file
%   bootstrapped - true if the parameter file exists (ndi.fun.probe.export.jrclust)
%   detected     - true if spikes have been detected ('jrc detect')
%   features     - true if the spike features JRCLUST's detect step writes
%                    (<session>_features.jrc) are still on disk. 'jrc sort' needs
%                    them: without them it stops with 'cannot sort without
%                    features', so a probe can be 'detected' and still not sortable
%                    if the intermediate files were cleaned up.
%   sorted       - true if the spikes have been sorted ('jrc sort')
%   curated      - true if the sort has been saved from the curator ('jrc manual'),
%                    i.e. JRCLUST stamped the file with curatedOn
%   annotated    - true if at least one unit carries a non-empty curation note. This
%                    is what the importer needs: it imports units by their note, and
%                    JRCLUST creates an empty note for every unit at sort time, so a
%                    sorted-but-unlabelled file is 'curated' only once saved and is
%                    never 'annotated' until a human labels units.
%   imported     - true if a 'jrclust_clusters' document for this probe is in the
%                    database (i.e. the sort has been imported into NDI)
%   upToDate     - true if the imported document's checksum matches the current
%                    results file; [] if it was not checked (see 'checksum')
%   checksum     - the MD5 checksum of the results file, if it was computed ('')
%
% This centralizes the pipeline-status logic so GUIs (e.g. ndi.gui.app.jrclust)
% stay thin wrappers over ndi.fun.probe.*.
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | jrclustDir ('.JRCLUST')  | Directory (within S.path) holding the JRCLUST work. |
% | prmName ('jrclust.prm')  | Name of the JRCLUST parameter file.                 |
% | checkDatabase (true)     | Look for a 'jrclust_clusters' document for PROBE.   |
% | checksum (false)         | Also checksum the results file to fill in upToDate. |
% |                          |   Off by default: the file can be large.            |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.JRCLUST.PATHS, NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE,
%   NDI.FUN.PROBE.EXPORT.JRCLUST
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    st = ndi.fun.probe.import.jrclust.status(S, p{1});
%

    arguments
        S
        probe
        options.jrclustDir (1,:) char = '.JRCLUST'
        options.prmName (1,:) char = 'jrclust.prm'
        options.checkDatabase (1,1) logical = true
        options.checksum (1,1) logical = false
    end

    P = ndi.fun.probe.import.jrclust.paths(S, probe, ...
        'jrclustDir', options.jrclustDir, 'prmName', options.prmName);

    s = struct();
    s.directory    = P.directory;
    s.prmFile      = P.prmFile;
    s.resFile      = P.resFile;
    s.featuresFile = P.featuresFile;
    % 'jrc sort' reads the features JRCLUST's detect step wrote; without that file
    % it stops with 'cannot sort without features', so report it separately from
    % whether spikes were detected.
    s.features     = isfile(P.featuresFile);
    s.bootstrapped = isfile(P.prmFile);
    s.detected     = false;
    s.sorted       = false;
    s.curated      = false;
    s.annotated    = false;
    s.imported     = false;
    s.upToDate     = [];
    s.checksum     = '';

    if isfile(P.resFile),
        try
            present = who('-file', P.resFile);
        catch
            present = {};
        end;
        % JRCLUST stamps the file at each stage: detectedOn in its detect step,
        % sortedOn in its sort step, and curatedOn only when the curator saves.
        % The presence of clusterNotes is NOT a sign of curation - JRCLUST creates
        % that field, with one empty note per unit, when the clustering is committed
        % during sorting - so 'curated' comes from curatedOn, and 'annotated' (what
        % the importer actually needs, since it imports units by their note) is
        % computed from the notes themselves.
        s.detected = ismember('spikeTimes', present) || ismember('detectedOn', present);
        s.sorted   = s.detected && ...
            (ismember('spikeClusters', present) || ismember('sortedOn', present));
        s.curated  = s.sorted && ismember('curatedOn', present);

        if s.sorted && ismember('clusterNotes', present),
            try
                n = load(P.resFile, 'clusterNotes');
                notes = n.clusterNotes;
                if ~iscell(notes),
                    notes = num2cell(notes);
                end;
                for i=1:numel(notes),
                    if (ischar(notes{i}) || isstring(notes{i})) && ...
                            ~isempty(strtrim(char(notes{i}))),
                        s.annotated = true;
                        break;
                    end;
                end;
            catch
                % unreadable notes: leave annotated false
            end;
        end;
    end;

    if options.checkDatabase,
        try
            q = ndi.query('','isa','jrclust_clusters','') & ...
                ndi.query('','depends_on','element_id', probe.id());
            docs = S.database_search(q);
        catch
            docs = {};
        end;
        s.imported = ~isempty(docs);
        if s.imported && options.checksum && isfile(P.resFile),
            s.checksum = ndi.fun.file.MD5(P.resFile);
            s.upToDate = false;
            for i=1:numel(docs),
                if strcmp(docs{i}.document_properties.jrclust_clusters.res_mat_MD5_checksum, ...
                        s.checksum),
                    s.upToDate = true;
                end;
            end;
        end;
    end;

end % status()
