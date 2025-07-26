function spikeStruct = probe2spiketimes(probe)
% PROBE2SPIKETIMES - retrieve all spike recordings and times from a probe
%
% SPIKESTRUCT = PROBE2SPIKETIMES(PROBE)
%
% Identifies all spike records (elements of type 'spike') that were
% recorded on a given PROBE. Then, creates a structure:
% |----------------|----------------------------------------|
% | Field          | Description                            |
% |----------------|----------------------------------------|
% | element_info   | Information about the element          |
% | epoch_data     | A structure with fields of all the data|
% |   epoch_id     | Epoch ID                               |
% |   spiketimes   | Spike times in the local epoch clock   |
% |   t0_t1        | Start and end times of the epoch in the|
% |                |   local epoch clock                    |
% | neuron_info    | Extracellular spike info               |
% |----------------|----------------------------------------|
% 

[ed,e] = ndi.example.fun.probe2elements(probe,'type','spikes');

spikeStruct = vlt.data.emptystruct('element_info','epoch_data','neuron_info');

for i=1:numel(e)
    spikeStruct(end+1) = ndi.example.fun.element2spiketimes(e{i},ed{i});
end

