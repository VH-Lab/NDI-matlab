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

p = S.getprobes();

ds = dirstruct(S.getpath);

[cells,cellnames] = load2celllist(getexperimentfile(ds),'cell*')

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
    all_intervals = [];
    for j=1:numel(et)
        interval_here = getintervalfromdir([S.getpath filesep et(j).epoch_id]);
        all_intervals = [all_intervals; interval_here];
    end
    ImatchesInAll = [];
    for j=1:size(I,1)
        ImatchesInAll(j) = NaN;
        for k=1:size(all_intervals,1)
            if all_intervals(k,1)==I(j,1) && all_intervals(k,2)==I(j,2)
                ImatchesInAll(j) = k;
                break;
            end
        end
    end

    if any(isnan(ImatchesInAll))
        error(['Could not find an epoch match: ' cellnames{i}])
    end

    % make an element
    dependency = {};
    element_neuron = ndi.neuron(S,[nameref.name '_' int2str(index)],...
		nameref.ref,'spikes',probeHere,0,[],dependency);

    % now make epochs
    for j=1:size(I,1)
        spikes_here = get_data(cells{j},[I(j,1) I(j,2)]);
        spike_times_here = spikes_here - I(j,1); % convert to dev_local_time
        t0_t1 = [0 I(j,2)-I(j,1)]; 
		element_neuron.addepoch(et(ImatchesInAll(j)).epoch_id,ndi.time.clocktype('dev_local_time'),...
			t0_t1,spike_times_here(:),ones(size(spike_times_here(:))));
    end
end



function [interval,starttime] = getintervalfromdir(dirname)
%dirname,
starttime = 0;
if exist([dirname filesep 'stims.mat'])&exist([dirname filesep 'stimtimes.txt']),
	g = load([dirname filesep 'stims.mat']);
	[mti2,starttime]=tpcorrectmti(g.MTI2,[dirname filesep 'stimtimes.txt'],1);
	interval = [starttime mti2{end}.frameTimes(end)+10]; % assume 10 sec of post recording
	interval = interval; % + g.start;
	starttime = g.start;
	clear g;
else,
    error(['could not find interval']);
end;
