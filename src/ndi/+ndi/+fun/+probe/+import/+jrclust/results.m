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
%   hasNotes        - true if the file carries a clusterNotes field (i.e. the sort
%                       has been through the curator)
%   detectedOn/sortedOn/curatedOn - the timestamps JRCLUST records ([] if absent)
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
