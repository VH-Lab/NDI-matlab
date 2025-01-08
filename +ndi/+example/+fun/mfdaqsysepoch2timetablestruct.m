function timetablestruct = mfdaqsysepoch2timetablestruct(dq, epoch)
% MFDAQSYSEPOCH2TIMETABLESTRUCT - extract all records of an mfdaq daq system to Matlab timetables
% 
% TIMETABLESTRUCT = MFDAQSYSEPOCH2TIMETABLESTRUCT(DQ, EPOCH)
%
% Given an ndi.system.mfdaq, create a structure of timetable objects.
% The structure will have one entry for all analog input data (ai),
% and another entry for all event data (event).
%
% Note that this will attempt to load all data from an epoch; if the
% epoch is very large, the program may run out of memory.
%
% EPOCH is a number or epoch_id of the epoch to be read.
%

arguments
    dq (1,1) ndi.daq.system.mfdaq
    epoch {ndi.validators.mustBeEpochInput(epoch)}
end

c = dq.getchannelsepoch(epoch);

event_tt = {};
analog_inputs = [];
analog_time_inputs = [];
digital_inputs = [];
digital_time_inputs = [];

for i=1:numel(c)
    if strcmp(c(i).type,'event') | strcmp(c(i).type,'marker') | strcmp(c(i).type,'text')
        [~,channelnumber] = ndi.fun.channelname2prefixnumber(c(i).name);
        [ts,value] = dq.readevents_epochsamples(c(i).type,channelnumber,epoch,-inf,inf);
        tt = timetable(seconds(ts),value,'VariableNames',{c(i).name});
        event_tt{end+1} = tt;
    elseif strcmp(c(i).type,'analog_in')
        [~,channelnumber] = ndi.fun.channelname2prefixnumber(c(i).name);        
        analog_inputs(end+1) = channelnumber;
        analog_time_inputs(end+1) = c(i).time_channel;
    elseif strcmp(c(i).type,'digital_in')
        [~,channelnumber] = ndi.fun.channelname2prefixnumber(c(i).name);        
        digital_inputs(end+1) = channelnumber;
        digital_time_inputs(end+1) = c(i).time_channel;        
    end
end

analog_tt = timetable(seconds());

if ~isempty(analog_inputs)
    analog_data = dq.readchannels_epochsamples('analog_in',analog_inputs,epoch,-inf,inf);
    analog_time = dq.readchannels_epochsamples('time',analog_time_inputs(1),epoch,-inf,inf);
    size(analog_data)
    analog_tt = timetable(seconds(analog_time),analog_data,'VariableNames',{'analog_inputs'});
end

digital_tt = timetable(seconds());

if ~isempty(digital_inputs)
    digital_data = dq.readchannels_epochsamples('analog_in',digital_inputs,epoch,-inf,5);
    digital_time = dq.readchannels_epochsamples('time',digital_time_inputs(1),epoch,-inf,5);
    digital_tt = timetable(seconds(digital_time),digital_data,'VariableNames',{'digital_inputs'});
end

timetablestruct.event_tt = event_tt;
timetablestruct.analog_tt = analog_tt;
timetablestruct.digital_tt = digital_tt;

