function R = results(resFile, options)
% NDI.FUN.PROBE.IMPORT.JRCLUST.RESULTS - read a JRCLUST results (_res.mat) file
%
% R = NDI.FUN.PROBE.IMPORT.JRCLUST.RESULTS(RESFILE, ...)
%
% Reads the JRCLUST results file RESFILE (usually 'jrclust_res.mat', written by
% 'jrc detect' / 'jrc sort' and updated by the curator 'jrc manual') and returns the
% pieces NDI needs, in a normalized form. Only the needed variables are loaded, so
% this is inexpensive even for a large results file.
%
% Fields of R:
%   resFile         - the file that was read
%   spikeSamples    - Nx1 double, the sample index of each spike (1-based) in the
%                       concatenated stream of the sorted recordings, in the order
%                       the .prm file's rawRecordings lists them
%   spikeClusters   - Nx1 double, the unit each spike is assigned to (<=0 means the
%                       spike was deleted / is unassigned)
%   unitIds         - 1xK double, the ids of the units in the sort
%   unitLabels      - 1xK string, each unit's curation note ("" if unannotated),
%                       e.g. "single", "multi", "noise"
%   spikesByCluster - 1xK cell, the indices (into spikeSamples) of each unit's spikes
%   unitCount       - 1xK double, the number of spikes in each unit
%   meanWfGlobal    - the mean filtered waveform of each unit over all sites, as
%                       [nSamples x nSites x K] ([] if not present in the file)
%   hasNotes        - true if the file carries a clusterNotes field. NOTE that this
%                       is NOT the same as having been curated: JRCLUST creates the
%                       field, with one empty note per unit, when the clustering is
%                       committed during 'jrc sort' (see
%                       jrclust.interfaces.Clustering/commit). Use 'annotated'.
%   annotated       - true if at least one unit carries a non-empty note, i.e. a
%                       human has been through 'jrc manual' and labelled units
%   annotatedCount  - the number of units carrying a non-empty note
%   detectedOn/sortedOn/curatedOn - the timestamps JRCLUST records ([] if absent).
%                       JRCLUST sets detectedOn in its detect step, sortedOn in its
%                       sort step, and curatedOn only when the curator saves, so
%                       curatedOn is the authoritative "this sort has been curated".
%
% Units are read from 'spikesByCluster' when JRCLUST stored it and are otherwise
% reconstructed from 'spikeClusters'.
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | needWaveforms (true)     | Load meanWfGlobal (the largest variable in the file).|
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE, NDI.FUN.PROBE.IMPORT.JRCLUST.READPRM,
%   NDI.FUN.PROBE.IMPORT.JRCLUST.STATUS
%
% Example:
%    R = ndi.fun.probe.import.jrclust.results('/path/to/jrclust_res.mat');
%    disp(R.unitLabels);
%

    arguments
        resFile (1,:) char {mustBeFile}
        options.needWaveforms (1,1) logical = true
    end

    present = who('-file', resFile);

    % A results file saved by an old JRCLUST holds the clustering as a saved
    % 'hClust' object rather than as the flat fields the current JRCLUST writes
    % (its saveRes/saveFiles flatten hClust before saving). NDI reads the flat
    % form; loading an object here would also need JRCLUST's class definitions.
    if ismember('hClust', present) && ~ismember('spikeClusters', present),
        error('ndi:fun:probe:import:jrclust:results:oldFormat', ...
            ['%s stores its clustering as a saved hClust object, which was written ' ...
            'by an older version of JRCLUST. Open it once in the current JRCLUST ' ...
            '(''jrc manual'') and save, which rewrites the file in the current ' ...
            'format, then import it.'], resFile);
    end;

    if ~ismember('spikeTimes', present),
        error('ndi:fun:probe:import:jrclust:results:noSpikes', ...
            ['%s has no spikeTimes; JRCLUST spike detection has not been run ' ...
            '(run ''jrc detect'').'], resFile);
    end;

    wanted = {'spikeTimes','spikeClusters','spikesByCluster','clusterNotes', ...
        'unitCount','detectedOn','sortedOn','curatedOn'};
    if options.needWaveforms,
        wanted{end+1} = 'meanWfGlobal';
    end;
    wanted = intersect(wanted, present, 'stable');
    res = load(resFile, wanted{:});

    R = struct();
    R.resFile = resFile;
    R.spikeSamples = double(res.spikeTimes(:));

    if isfield(res,'spikeClusters') && ~isempty(res.spikeClusters),
        R.spikeClusters = double(res.spikeClusters(:));
    else,
        error('ndi:fun:probe:import:jrclust:results:noClusters', ...
            ['%s has no spikeClusters; the spikes have been detected but not sorted ' ...
            '(run ''jrc sort'').'], resFile);
    end;

    if numel(R.spikeClusters) ~= numel(R.spikeSamples),
        error('ndi:fun:probe:import:jrclust:results:inconsistent', ...
            ['%s holds %d spike times but %d cluster assignments. The file is in an ' ...
            'inconsistent state; open it in JRCLUST (''jrc manual''), let it recover ' ...
            'the clustering, and save before importing.'], resFile, ...
            numel(R.spikeSamples), numel(R.spikeClusters));
    end;

    if isfield(res,'spikesByCluster') && ~isempty(res.spikesByCluster),
        sbc = res.spikesByCluster(:)';
        R.unitIds = 1:numel(sbc); % JRCLUST indexes units 1..K by position
        R.spikesByCluster = cellfun(@(x) double(x(:)), sbc, 'UniformOutput', false);
    else,
        R.unitIds = reshape(unique(R.spikeClusters(R.spikeClusters>0)),1,[]);
        R.spikesByCluster = arrayfun(@(u) find(R.spikeClusters==u), R.unitIds, ...
            'UniformOutput', false);
    end;

    nUnits = numel(R.unitIds);

    if isfield(res,'unitCount') && numel(res.unitCount)==nUnits,
        R.unitCount = double(reshape(res.unitCount,1,[]));
    else,
        R.unitCount = cellfun(@numel, R.spikesByCluster);
    end;

    % JRCLUST creates clusterNotes (one empty note per unit) when the clustering is
    % committed during sorting, so the field's presence says nothing about whether a
    % human has annotated anything: that is what 'annotated' reports.
    R.hasNotes = isfield(res,'clusterNotes');
    R.unitLabels = repmat("", 1, nUnits);
    if R.hasNotes,
        notes = res.clusterNotes;
        if ~iscell(notes),
            notes = num2cell(notes);
        end;
        for i=1:nUnits,
            % JRCLUST's notes are indexed by unit id (which is the unit's position
            % whenever spikesByCluster is present)
            idx = R.unitIds(i);
            if idx>=1 && idx<=numel(notes),
                n = notes{idx};
                if ischar(n) || isstring(n),
                    R.unitLabels(i) = strtrim(string(n));
                end;
            end;
        end;
    end;

    R.annotatedCount = sum(strlength(R.unitLabels)>0);
    R.annotated = R.annotatedCount > 0;

    R.meanWfGlobal = [];
    if options.needWaveforms && isfield(res,'meanWfGlobal'),
        R.meanWfGlobal = res.meanWfGlobal;
    end;

    for f = {'detectedOn','sortedOn','curatedOn'},
        if isfield(res,f{1}),
            R.(f{1}) = res.(f{1});
        else,
            R.(f{1}) = [];
        end;
    end;

end % results()
