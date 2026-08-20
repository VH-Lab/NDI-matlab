function probe(S, probe, options)
% NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE - import JRCLUST spike sorting results into NDI
%
% NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE(S, PROBE, ...)
%
% Imports the JRCLUST sort of an ndi.probe (or ndi.element) PROBE that is part of the
% ndi.session S. For each sorted unit whose curation note passes the quality filter,
% this function creates:
%
%   1) an ndi.neuron element named [PROBE.name '_' PROBE.reference '_' N], where N is
%      the JRCLUST unit id, with the unit's spike times added as epochs (mapped back
%      from JRCLUST's concatenated sample stream into each NDI epoch's local time), and
%   2) a 'neuron_extracellular' ndi.document holding the mean waveform, sample counts,
%      cluster index and quality (label/number) for that neuron.
%
% This is the import side of the NDI/JRCLUST pipeline (see NDI.FUN.PROBE.EXPORT.JRCLUST
% for the export side), and the JRCLUST analog of NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE
% and NDI.FUN.PROBE.IMPORT.KIASORT.PROBE. It reads JRCLUST's own files,
%
%       [S.path]/.JRCLUST/[element string]/jrclust.prm       the parameters
%       [S.path]/.JRCLUST/[element string]/jrclust_res.mat   the results
%
% so JRCLUST itself does not have to be installed to import a sort that has already
% been run and curated.
%
% ANNOTATION: JRCLUST records each unit's curation note (set in 'jrc manual', see
% NDI.FUN.PROBE.IMPORT.JRCLUST.CURATE). By default the units noted 'single' (imported
% with quality_number 1) and 'multi' (quality_number 4) are imported and every other
% unit, including unannotated ones, is skipped. Change that with 'qualityLabels' and
% 'qualityValues'.
%
% SPIKE TIMES: JRCLUST spike times are 1-based sample indices into the concatenated
% stream of the recordings the parameter file lists in 'rawRecordings', which for the
% 'ndi' recording format are NDI epoch ids. This function rebuilds those boundaries
% from the probe itself (the sample count of each epoch, in the parameter file's
% order) and errors
% (ndi:fun:probe:import:jrclust:probe:sampleOutOfRange) if any spike falls outside
% them, which would mean the sort does not correspond to this probe.
%
% IDEMPOTENCY: a 'jrclust_clusters' ndi.document is created that depends on PROBE and
% stores the MD5 checksum of the results file. If the checksum is unchanged since a
% previous import this function does nothing (unless 'force' is 1); if it has changed,
% the previously imported neurons and documents are removed and the import is repeated.
% The document is the same class that JRCLUST's own jrclust.export.ndi writes, so an
% import made either way is recognized here.
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | jrclustDir ('.JRCLUST')  | Directory (within S.path) holding the JRCLUST work. |
% | prmName ('jrclust.prm')  | Name of the JRCLUST parameter file.                 |
% | qualityLabels            | String array of curation notes to import (matched   |
% |   (["single","multi"])   |   case-insensitively).                              |
% | qualityValues ([1 4])    | quality_number assigned to each label (parallel).   |
% | checkElement (true)      | Verify that the parameter file's ndiElementName /   |
% |                          |   ndiElementReference match PROBE.                  |
% | force (0)                | Re-import even if the checksum is unchanged.        |
% | dryRun (false)           | Report what would be imported without changing the  |
% |                          |   database.                                         |
% | progressbar (false)      | Show an ndi.gui.component.ProgressBarWindow.        |
% | verbose (1)              | 0/1 Should we be verbose?                           |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.EXPORT.JRCLUST, NDI.FUN.PROBE.IMPORT.JRCLUST.SESSION,
%   NDI.FUN.PROBE.IMPORT.JRCLUST.CURATE, NDI.FUN.PROBE.IMPORT.KIASORT.PROBE
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    ndi.fun.probe.import.jrclust.probe(S, p{1});
%

    arguments
        S
        probe
        options.jrclustDir (1,:) char = '.JRCLUST'
        options.prmName (1,:) char = 'jrclust.prm'
        options.qualityLabels (1,:) string = ["single","multi"]
        options.qualityValues (1,:) double = [1 4]
        options.checkElement (1,1) logical = true
        options.force (1,1) double = 0
        options.dryRun (1,1) logical = false
        options.progressbar (1,1) logical = false
        options.verbose (1,1) double = 1
    end

    if numel(options.qualityLabels)~=numel(options.qualityValues),
        error('qualityLabels and qualityValues must have the same number of elements.');
    end;

    verbose = options.verbose;
    dryRun = options.dryRun;
    % In a dry run we always report the plan, regardless of the verbose setting.
    report = verbose || dryRun;
    if dryRun, pfx = '[dry run] '; else, pfx = ''; end;

    % Step 1: locate JRCLUST's files for this probe

    P = ndi.fun.probe.import.jrclust.paths(S, probe, ...
        'jrclustDir', options.jrclustDir, 'prmName', options.prmName);

    if ~isfile(P.prmFile),
        error('ndi:fun:probe:import:jrclust:probe:noPrmFile', ...
            ['No JRCLUST parameter file at %s. Was this probe prepared with ' ...
            'ndi.fun.probe.export.jrclust?'], P.prmFile);
    end;
    if ~isfile(P.resFile),
        error('ndi:fun:probe:import:jrclust:probe:noResFile', ...
            ['No JRCLUST results file at %s. Detect and sort the spikes first ' ...
            '(ndi.fun.probe.import.jrclust.run).'], P.resFile);
    end;

    prm = ndi.fun.probe.import.jrclust.readprm(P.prmFile);

    if options.checkElement,
        nameOK = isempty(prm.ndiElementName) || strcmp(prm.ndiElementName, probe.name);
        refOK  = isempty(prm.ndiElementReference) || ...
            isequal(double(prm.ndiElementReference), double(probe.reference));
        if ~nameOK || ~refOK,
            error('ndi:fun:probe:import:jrclust:probe:elementMismatch', ...
                ['%s was created for element ''%s'' reference %s, but it is being ' ...
                'imported for element ''%s'' reference %d. Pass ''checkElement'',false ' ...
                'to import it anyway.'], P.prmFile, prm.ndiElementName, ...
                mat2str(prm.ndiElementReference), probe.name, probe.reference);
        end;
    end;

    if report,
        disp([pfx 'Importing JRCLUST results for probe ' P.elementString ' from ' P.resFile '.']);
    end;

    % Step 2: idempotency - has this sort already been imported?

    md5Value = ndi.fun.file.MD5(P.resFile);

    qExisting = ndi.query('','isa','jrclust_clusters','') & ...
        ndi.query('','depends_on','element_id', probe.id());
    oldDocs = S.database_search(qExisting);

    if ~isempty(oldDocs),
        if numel(oldDocs)==1 && ~options.force,
            existingMD5 = oldDocs{1}.document_properties.jrclust_clusters.res_mat_MD5_checksum;
            if strcmp(existingMD5, md5Value),
                if report,
                    disp([pfx 'Sort is unchanged since the last import; nothing to do ' ...
                        '(use ''force'',1 to re-import).']);
                end;
                return;
            end;
        end;
        if report,
            disp([pfx 'Would remove ' int2str(numel(oldDocs)) ' previously imported JRCLUST ' ...
                'cluster document(s) and their dependent neurons.']);
        end;
        if ~dryRun,
            for i=1:numel(oldDocs),
                ndi.fun.probe.import.jrclust.removeOld(S, oldDocs{i});
            end;
        end;
    end;

    % Step 3: read the sort

    R = ndi.fun.probe.import.jrclust.results(P.resFile);

    if ~R.hasNotes,
        error('ndi:fun:probe:import:jrclust:probe:notAnnotated', ...
            ['The units in %s have not been annotated. Open the curation GUI ' ...
            '(ndi.fun.probe.import.jrclust.curate), annotate each unit (''single'', ' ...
            '''multi'', ''noise'', ...) and save before importing.'], P.resFile);
    end;

    % Step 4: rebuild the epoch boundaries of JRCLUST's concatenated sample stream.
    % The parameter file's rawRecordings list is the authority on which epochs were
    % sorted and in what order; the sample count of each comes from the probe, the
    % same way JRCLUST's ndiRecording computes it.

    et = probe.epochtable();
    allEpochIds = {et.epoch_id};

    epochIds = prm.rawRecordings;
    if isempty(epochIds),
        error('ndi:fun:probe:import:jrclust:probe:noRecordings', ...
            'No rawRecordings are listed in %s.', P.prmFile);
    end;

    nEpochs = numel(epochIds);
    epochCounts = zeros(nEpochs,1);
    epochT0T1 = cell(nEpochs,1);
    epochClock = cell(nEpochs,1);

    for e=1:nEpochs,
        match = find(strcmp(epochIds{e}, allEpochIds),1);
        if isempty(match),
            error('ndi:fun:probe:import:jrclust:probe:noSuchEpoch', ...
                ['%s lists a recording (''%s'') that is not an epoch of probe %s. The ' ...
                'sort does not correspond to this probe.'], P.prmFile, epochIds{e}, ...
                P.elementString);
        end;
        % the dev_local_time clock, in which spike times are stored
        found = 0;
        for c=1:numel(et(match).epoch_clock),
            if strcmp(et(match).epoch_clock{c}.type,'dev_local_time'),
                found = c; break;
            end;
        end;
        if ~found,
            error(['Epoch ' epochIds{e} ' has no ''dev_local_time'' clock.']);
        end;
        epochClock{e} = et(match).epoch_clock{found};
        epochT0T1{e} = et(match).t0_t1{found};
        ss = probe.times2samples(epochIds{e}, epochT0T1{e});
        epochCounts(e) = 1 + diff(ss); % matches jrclust.detect.ndiRecording
    end;

    bounds = [0; cumsum(epochCounts)]; % 1-based spikes fall in (bounds(e), bounds(e+1)]
    totalSamples = bounds(end);

    if ~isempty(R.spikeSamples),
        nOverrun = sum(R.spikeSamples > totalSamples | R.spikeSamples < 1);
        if nOverrun>0,
            error('ndi:fun:probe:import:jrclust:probe:sampleOutOfRange', ...
                ['%d of %d spike sample indices fall outside the sorted epochs ' ...
                '[1, %d]. The largest spike sample index is %d. This usually means the ' ...
                'JRCLUST results were produced from a different set of epochs than the ' ...
                'ones listed in %s, or from a probe with a different sample rate.'], ...
                nOverrun, numel(R.spikeSamples), totalSamples, max(R.spikeSamples), P.prmFile);
        end;
    end;

    sampleRate = prm.sampleRate;

    % waveform sample times, relative to the spike peak, from the parameter file
    waveformTimes = (prm.evtWindowSamp(1):prm.evtWindowSamp(2))' / sampleRate;

    % Step 5: provenance/cluster document (the neurons will depend on it)

    % These neurons are produced by an external pipeline (JRCLUST, then curation,
    % then this importer). The 'app' sub-document describes one app, so we record
    % the pipeline in 'app.name' and the JRCLUST version (if it can be read) in
    % 'app.version'.
    matlabVer = ver('MATLAB');
    jrcVersion = '';
    try
        installInfo = ndi.fun.probe.import.jrclust.install();
        jrcVersion = installInfo.version;
    catch
        % JRCLUST need not be installed to import a finished sort
    end;
    appStruct = struct('name','JRCLUST to ndi.fun.probe.import.jrclust', ...
        'version', jrcVersion, ...
        'url','https://github.com/VH-Lab/JRCLUST', ...
        'os', computer, 'os_version','', ...
        'interpreter','MATLAB','interpreter_version', matlabVer.Version);

    if ~dryRun,
        jc = ndi.document('jrclust_clusters','app',appStruct, ...
            'base.session_id', S.id(), ...
            'base.name', options.prmName, ...
            'jrclust_clusters.res_mat_MD5_checksum', md5Value);
        jc = jc.set_dependency_value('element_id', probe.id());
        S.database_add(jc);
    end;

    % Step 6: assemble each unit that passes the quality filter, then commit them all
    % in batched database writes via ndi.element.timeseries.addMultiple.

    wantLabels = lower(string(options.qualityLabels));

    specs = struct('name',{},'reference',{},'type',{},'epochs',{},'extra_documents',{});
    nImported = 0;

    for ci=1:numel(R.unitIds),
        cid = R.unitIds(ci);
        thisLabel = lower(strtrim(R.unitLabels(ci)));
        match = find(wantLabels==thisLabel,1);
        if isempty(match),
            if report,
                if strlength(thisLabel)==0,
                    disp([pfx '  Unit ' int2str(cid) ' (not annotated) skipped.']);
                else,
                    disp([pfx '  Unit ' int2str(cid) ' (note ''' char(R.unitLabels(ci)) ''') skipped.']);
                end;
            end;
            continue;
        end;
        qnum = options.qualityValues(match);

        spikeIndexes = R.spikesByCluster{ci};
        g = R.spikeSamples(spikeIndexes); % 1-based global samples
        nImported = nImported + 1;

        % the neuron name includes the probe reference so that neurons from probes
        % that share a name are distinguishable: <probe name>_<reference>_<unit id>
        neuronName = [probe.name '_' int2str(probe.reference) '_' int2str(cid)];

        if dryRun,
            disp([pfx '  Would import unit ' int2str(cid) ' as neuron ' neuronName ...
                ' (' char(R.unitLabels(ci)) ', quality ' int2str(qnum) ', ' ...
                int2str(numel(g)) ' spikes), with a neuron_extracellular document and ' ...
                'spike trains across ' int2str(nEpochs) ' epoch(s).']);
            continue;
        end;

        % the mean waveform over all sites, [nSamples x nSites]
        meanWf = [];
        if ~isempty(R.meanWfGlobal) && size(R.meanWfGlobal,3)>=cid,
            % meanWfGlobal's third dimension is indexed by unit id
            meanWf = double(R.meanWfGlobal(:,:,cid));
        end;
        wst = waveformTimes;
        if ~isempty(meanWf) && numel(wst)~=size(meanWf,1),
            % the parameter file and the results file disagree about the waveform
            % window (the file was edited after sorting); center the times instead
            warning('ndi:fun:probe:import:jrclust:probe:waveformWindow', ...
                ['The evtWindow in %s implies %d waveform samples but the results ' ...
                'hold %d; using a window centered on the peak instead.'], ...
                P.prmFile, numel(wst), size(meanWf,1));
            [~, troughSample] = min(min(meanWf,[],2));
            wst = ((0:size(meanWf,1)-1)' - (troughSample-1)) / sampleRate;
        end;

        ne = struct();
        ne.number_of_samples_per_channel = max(size(meanWf,1),1);
        ne.number_of_channels = max(size(meanWf,2),1);
        ne.mean_waveform = meanWf;
        ne.waveform_sample_times = wst;
        ne.cluster_index = cid;
        ne.quality_number = qnum;
        ne.quality_label = char(R.unitLabels(ci));

        % the neuron_extracellular document (addMultiple sets its element_id)
        neuronDoc = ndi.document('neuron_extracellular','app',appStruct, ...
            'neuron_extracellular', ne, 'base.session_id', S.id());
        neuronDoc = neuronDoc.set_dependency_value('spike_clusters_id', jc.id());

        % the spike trains, one entry per sorted epoch (empty where there are no spikes)
        clear epochs;
        for e=1:nEpochs,
            inEpoch = find(g > bounds(e) & g <= bounds(e+1));
            if isempty(inEpoch),
                spikeTimesLocal = [];
            else,
                local1 = g(inEpoch) - bounds(e); % 1-based sample within the epoch
                spikeTimesLocal = probe.samples2times(epochIds{e}, double(local1));
                spikeTimesLocal = spikeTimesLocal(:);
            end;
            % wrap array-valued fields in cells so struct() stores them as-is
            epochs(e) = struct('epoch_id', epochIds{e}, 'epoch_clock', epochClock(e), ...
                't0_t1', {epochT0T1{e}}, 'timepoints', {spikeTimesLocal}, ...
                'datapoints', {ones(size(spikeTimesLocal))}); %#ok<AGROW>
        end;

        specs(end+1) = struct('name', neuronName, 'reference', probe.reference, ...
            'type', 'spikes', 'epochs', {epochs}, ...
            'extra_documents', {{neuronDoc}}); %#ok<AGROW>

        if verbose,
            disp(['  Prepared unit ' int2str(cid) ' as neuron ' neuronName ...
                ' (' char(R.unitLabels(ci)) ', ' int2str(numel(g)) ' spikes).']);
        end;
    end;

    if ~dryRun && ~isempty(specs),
        ndi.element.timeseries.addMultiple(S, probe, specs, ...
            'element_class','ndi.neuron', ...
            'progressbar', options.progressbar, ...
            'verbose', logical(verbose));
    end;

    if report,
        if dryRun,
            disp([pfx 'Done. Would import ' int2str(nImported) ' neuron(s) for probe ' ...
                P.elementString '. No changes were made to the database.']);
        else,
            disp(['Done. Imported ' int2str(nImported) ' neuron(s) for probe ' P.elementString '.']);
        end;
    end;

end % probe()
