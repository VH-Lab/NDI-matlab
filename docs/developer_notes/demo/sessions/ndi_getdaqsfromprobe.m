function [daqnames, channel_types, channels, epochids, subject] = ndi_getdaqsfromprobe(ndi_probe_obj)
% NDI_GETDAQSFROMPROBE - return DAQ objects that are connected to a probe
% 
% [DAQNAMES, CHANNEL_TYPES, CHANNELS, EPOCHIDS, SUBJECT] = ndi.demo.session.getdaqsfromprobe(NDI_PROBE_OBJ)
%
% Return the DAQNAMES, CHANNEL_TYPES, CHANNELS, EPOCHIDS, and SUBJECT connected to a probe.
% DAQs and CHANNELS are a cell array the same size as the number of epochs
% of NDI_PROBE_OBJ, as the connected DAQ and CHANNELS could potentially vary
% from epoch to epoch.
%
% SUBJECT is a single ndi.document object for the subject.
% 

subject_id = ndi_probe_obj.subject_id;
subject = ndi_probe_obj.session.database_search(ndi.query('ndi.document.id','exact_string',subject_id,''));

et = ndi_probe_obj.epochtable();

epochids = {et.epoch_id};
daqnames = {};
channel_types = {};
channels = {};

for i=1:numel(et),
    [DEV, DEVNAME, DEVEPOCH, CHANNELTYPE, CHANNELLIST] = getchanneldevinfo(ndi_probe_obj, et(i).epoch_id);
    daqnames{i} = DEVNAME;
    channel_types{i} = CHANNELTYPE;
    channels{i} = CHANNELLIST;
end;


