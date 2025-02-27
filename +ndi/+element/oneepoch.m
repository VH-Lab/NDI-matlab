function elem_out = oneepoch(D, ndi_element_timeseries_obj_in, name_out, reference_out)
% ONEEPOCH - make a 1 epoch version of an ndi.element.timeseries
% 
% ELEM_OUT = ONEEPOCH(D, NDI_ELEMENT_TIMESERIES_OBJ_IN, NAME_OUT, REFERENCE_OUT)
%
% Creates a concatenated version of an ndi.element.timeseries (or ndi.probe.timeseries).
% Use with caution, as this could create enormous documents. The new object
% will have the name NAME_OUT and reference REFERENCE_OUT. The original
% object will not be modified.
%
% The epoch will be created with the most "global" clock available. The preferred order
% is 'utc','approx_utc','exp_global_time','approx_exp_global_time','dev_global_time','approx_dev_global_time'.
% If a global clock cannot be found, the epoch will be given a 'dev_local_time' with the concatenation
% of all the local times as though the recordings occurred one immediately after the other.
% 
%   Inputs:
%       D - The ndi.dataset or ndi.session object containing the data.
%       NDI_ELEMENT_TIMESERIES_OBJ_IN - The ndi.element.timeseries object
%                                       to concatenate.
%       NAME_OUT - The name of the new ndi.element.timeseries object.
%       REFERENCE_OUT - The reference number of the new
%                      ndi.element.timeseries object.
%
%   Outputs:
%       ELEM_OUT - The new concatenated ndi.element.timeseries object.
%
%   See also: NDI.ELEMENT.TIMESERIES
%

arguments
    D {mustBeA(D, ["ndi.session", "ndi.dataset"])}
    ndi_element_timeseries_obj_in (1,1) {mustBeA(ndi_element_timeseries_obj_in, ["ndi.probe.timeseries", "ndi.element.timeseries"])}
    name_out (1,:) char
    reference_out (1,1) double {mustBeNonnegative}
end

mylog = ndi.common.getLogger();

 % first check to see if it already exists

e = D.getelements('element.name',name_out,'element.reference',reference_out);

if ~isempty(e),
	D.database_rm(e{1}.id());
	e = [];
end;

assert(isempty(e),['Element with name ' name_out ' and reference ' int2str(reference_out) ' already exists. Delete it before making a new one.']);

% Create the new ndi.element.timeseries object
elem_out = ndi.element.timeseries(D, name_out, reference_out,...
    ndi_element_timeseries_obj_in.type,...
    ndi_element_timeseries_obj_in,...
    false); % not direct

% Get the epoch table
et = ndi_element_timeseries_obj_in.epochtable();

data = [];
time = [];

nextTime = zeros(1,numel(et(1).epoch_clock));
t0_t1 = zeros(2,numel(et(1).epoch_clock));
idx_dev_local_time = find(cellfun(@(x) eq(ndi.time.clocktype('dev_local_time'),x),et(1).epoch_clock));


for i=1:numel(et)
    mylog.msg('system',5,...
        ['Working on new element ' name_out ' : ' int2str(reference_out) ...
        ', subepoch ' int2str(i) ' of ' int2str(numel(et)) '.']);    
    [d,t] = ndi_element_timeseries_obj_in.readtimeseries(i,-inf,inf);
    time = cat(1,time,nextTime(1,idx_dev_local_time) + t(:));
    data = cat(1,data,d);    for k=1:numel(et(i).epoch_clock),
        if i==1
            t0_t1(1,k) = et(1).t0_t1{k}(1);
        end
        nextTime(1,k) = nextTime(1,k) + et(i).t0_t1{k}(2) - et(i).t0_t1{k}(1);
    end;
end

ecs = {};
for k=1:numel(et(1).epoch_clock)
    ecs{k} = et(1).epoch_clock{k}.type;
    t0_t1(2,k) = t0_t1(1,k) + nextTime(k);
end

epoch_id = ['whole_session_' ndi_element_timeseries_obj_in.session.reference];

[elem_out,epochdoc] = elem_out.addepoch(epoch_id,...
        strjoin(ecs,','), t0_t1, time, data);

D.database_add(epochdoc);
