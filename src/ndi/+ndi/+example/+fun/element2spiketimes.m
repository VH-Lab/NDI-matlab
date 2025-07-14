function spikeStruct = element2spiketimes(e, ed)
% ELEMENT2SPIKETIMES - retrieve spike times from an element
%
% SPIKESTRUCT = ELEMENT2SPIKETIMES(E, ED)
%
% Given an element E and its corresponding element document ED, this function
% retrieves all spike times and related information. It returns a structure:
% |----------------|----------------------------------------|
% | Field          | Description                            |
% |----------------|----------------------------------------|
% | element_info   | Information about the element          |
% | epoch_data     | A structure with fields of all the data|
% |   epoch_id     | Epoch ID                               |
% |   spiketimes   | Spike times in the local epoch clock   |
% |   t0_t1        | Start and end times of the epoch in the|
% |                |   local epoch clock                    |
% | neuron_info    | Extracellular spike info (if available)|
% |----------------|----------------------------------------|
%
% This function assumes that E is an element of type 'spikes'.
%
% Example:
%   [ed, e] = ndi.example.fun.probe2elements(probe, 'type', 'spikes');
%   spikeStruct = element2spiketimes(e{1}, ed{1});

% Extract element information
spikeStruct.element_info = ed.document_properties.element;

% Search for associated neuron information (if any)
nid_q1 = ndi.query('','depends_on','element_id',e.id());
nid_q2 = ndi.query('','isa','neuron_extracellular');
nid = e.session.database_search(nid_q1&nid_q2); 
if isempty(nid)
    spikeStruct.neuron_info = [];
else
    spikeStruct.neuron_info = nid{1}.document_properties.neuron_extracellular;
end

% Extract spike times for each epoch
et = e.epochtable();
epoch_data = vlt.data.emptystruct('epoch_id','spiketimes','t0_t1');
for j=1:numel(et)
    epoch_data_here.epoch_id = et(j).epoch_id;
    [values,epoch_data_here.spiketimes] = e.readtimeseries(et(j).epoch_id,-inf,inf);
    epoch_data_here.t0_t1 = et(j).t0_t1{1};
    epoch_data(end+1) = epoch_data_here;
end
spikeStruct.epoch_data = epoch_data;
end
