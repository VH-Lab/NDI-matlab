function b = importMeasuredDataCells(S)
% importMeasuredDataCells - import VH-lab style extracellular cells into NDI
%
% B = IMPORTMEASUREDDATACELL(S)
%
% S - an ndi.session object that is at the path of an old-school VH lab experiment
% that can also be managed by dirstruct.
%

arguments
	S (1,1) ndi.session.dir
end

ds = dirstruct(S.getpath);

[cells,cellnames] = load2celllist(getexperimentfile(ds),'cell*','-mat');

for i=1:numel(cells)
    disp(['Working on cell ' int2str(i) ' of ' int2str(numel(cells)) ': ' cellnames{i}]);
    [nameref,index] = cellname2nameref(cellnames{i});
    I = get_intervals(cells{i});
    probeHere = S.getprobes('name',nameref.name,'reference',nameref.ref);
    if isempty(probeHere)
        error(['Could not find probe for cell ' cellnames{i} '.']);
    elseif numel(probeHere)>1
        error(['Too many probes for cell ' cellnames{i} '.']);
    else
        probeHere = probeHere{1};
    end

    et = probeHere.epochtable();
    all_intervals = nan(numel(et),2);
    all_global_starts = nan(numel(et),1);
    for j=1:numel(et)
        [all_intervals(j,:), all_global_starts(j)] = getintervalfromdir([S.getpath filesep et(j).epoch_id]);
    end
    % the cell's stored intervals can differ slightly from the recomputed ones
    ImatchesInAll = ndi.setup.conv.vhlab.matchCellIntervalsToEpochs(I, all_intervals);
    for j = find(isnan(ImatchesInAll(:)))'
        warning('ndi:setup:conv:vhlab:importMeasuredDataCells:NoEpoch', ...
            'Cell %s: no epoch of probe %s | %d matches interval [%.3f %.3f]; its spikes there are not imported.', ...
            cellnames{i}, nameref.name, nameref.ref, I(j,1), I(j,2));
    end
    I = I(~isnan(ImatchesInAll), :);
    ImatchesInAll = ImatchesInAll(~isnan(ImatchesInAll));
    if isempty(ImatchesInAll)
        warning('ndi:setup:conv:vhlab:importMeasuredDataCells:NoEpochs', ...
            'Cell %s matches no epoch of probe %s | %d; skipping it.', cellnames{i}, nameref.name, nameref.ref);
        continue;
    end

    % make an element
    dependency = {};
    element_neuron = ndi.neuron(S,[nameref.name '_' int2str(index)],...
		nameref.ref,'spikes',probeHere,0,[],dependency);

    % now make epochs
    for j=1:size(I,1)
        epoch_here = et(ImatchesInAll(j));
        spikes_here = get_data(cells{i},[I(j,1) I(j,2)]);
        % Legacy spike times are on the legacy global clock, which is the Spike2
        % (stimulator) clock plus stims.mat's start (see vhlabcorrectmti with
        % globaltime = 1). Subtract it to get the stimulator's dev_local_time,
        % then convert to the probe's own clock through the syncgraph.
        spike_times_stim = spikes_here(:) - all_global_starts(ImatchesInAll(j));
        spike_times_here = stimulatorTimeToProbeTime(S, spike_times_stim, epoch_here.epoch_id, probeHere);
        t0_t1 = epoch_here.t0_t1{find(cellfun(@(c) c==ndi.time.clocktype('dev_local_time'), epoch_here.epoch_clock), 1)};
		element_neuron.addepoch(epoch_here.epoch_id,ndi.time.clocktype('dev_local_time'),...
			t0_t1,spike_times_here(:),ones(size(spike_times_here(:))));
    end
end



function [interval,global_start] = getintervalfromdir(dirname)
% GETINTERVALFROMDIR - the legacy interval of an epoch directory, and stims.mat's start
%
% INTERVAL is the interval the legacy analysis stored with each cell, used here
% only to match a cell's intervals to epochs. GLOBAL_START is g.start from
% stims.mat: legacy global time = Spike2 time + GLOBAL_START.
if exist([dirname filesep 'stims.mat'])&exist([dirname filesep 'stimtimes.txt']),
	g = load([dirname filesep 'stims.mat']);
	[mti2,starttime]=tpcorrectmti(g.MTI2,[dirname filesep 'stimtimes.txt'],1);
	interval = [starttime mti2{end}.frameTimes(end)+10]; % assume 10 sec of post recording
	global_start = g.start;
	clear g;
else,
    error(['could not find interval']);
end;


function t_probe = stimulatorTimeToProbeTime(S, t_stim, epoch_id, probe)
% STIMULATORTIMETOPROBETIME - convert times from the stimulator's dev_local_time to PROBE's
stimprobes = S.getprobes('type','stimulator');
if isempty(stimprobes)
    error('Could not find a stimulator probe.');
end
ct = ndi.time.clocktype('dev_local_time');
tr = ndi.time.timereference(stimprobes{1}, ct, epoch_id, 0);
[t_probe, ~, msg] = S.syncgraph.time_convert(tr, t_stim, probe, ct);
if isempty(t_probe) && ~isempty(t_stim)
    error(['Could not convert stimulator time to probe time for epoch ' epoch_id ': ' msg]);
end
