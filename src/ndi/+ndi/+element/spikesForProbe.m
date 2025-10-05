function ndi_neuron_obj = spikesForProbe(ndi_session_obj, ndi_probe_obj, name, reference, spikedata)
% SPIKESFORPROBE - create a spiking neuron element from an ndi.probe and spike data
%
% NDI_NEURON_OBJ = ndi.element.spikesForProbe(NDI_SESSION_OBJ, NDI_PROBE_OBJ, NAME, REFERENCE, SPIKEDATA)
%
% Creates a new NDI_NEURON_OBJ, which is an NDI_ELEMENT of type 'neuron.spikes'.
%
% The element is given the name NAME and reference number REFERENCE. The reference number is used
% as the unit_id for the neuron.
%
% SPIKEDATA is a structure array with fields:
% 'epochid'                 | The epoch id (string)
% 'spiketimes'              | A vector of spike times (in the NDI_PROBE_OBJ's clock time)
%
% This function creates the new element and adds the spike data for each epoch provided.
%
% Example:
%   S = getmysession(); % returns my session
%   myprobe = ndi.probe(S, 'myprobe', 1, 'n-trode');
%   spikedata(1).epochid = 'exp1_run1';
%   spikedata(1).spiketimes = [ 0.01 0.02 0.03 ];
%   spikedata(2).epochid = 'exp1_run2';
%   spikedata(2).spiketimes = [ 1.01 1.02 1.03 ];
%   myneuron = ndi.element.spikesForProbe(S, myprobe, 'unit1', 1, spikedata);
%

subject_id = []; % take subject from the probe
dependencies = struct('name',{'channel','unit_id'},'value',{0,reference});
ndi_neuron_obj = ndi.neuron(ndi_session_obj, name, reference, 'neuron.spikes', ndi_probe_obj, 0, subject_id, dependencies);

et = ndi_probe_obj.epochtable();

for i=1:numel(spikedata)
	epoch_here = spikedata(i).epochid;
	spiketimes_here = spikedata(i).spiketimes;

	% find the matching epoch in the probe's epoch table
	epoch_entry_num = find(strcmp(epoch_here, {et.epoch_id}));
	if isempty(epoch_entry_num)
		error(['Could not find epoch with id ' epoch_here ' in the probe.']);
	end
	if numel(epoch_entry_num)>1
		error(['Found more than one epoch with id ' epoch_here ' in the probe.']);
	end

	et_here = et(epoch_entry_num);

	% we will use the first clock type available
	clock_here = et_here.epoch_clock{1};
	t0_t1 = et_here.t0_t1{1};

	% the data is just the spike times
	data = spiketimes_here(:); % ensure it is a column vector

	ndi_neuron_obj.addepoch(epoch_here, clock_here, t0_t1, spiketimes_here, data);
end