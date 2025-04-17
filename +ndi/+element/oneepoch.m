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

e = D.getelements('element.name',name_out,'element.reference',reference_out);

% Get the epoch table and find earliest epoch from exp_global_time t0
et = ndi_element_timeseries_obj_in.epochtable();
idx_exp_global_time = find(cellfun(@(x) eq(ndi.time.clocktype('exp_global_time'),x),et(1).epoch_clock));
et_t0_t1 = vertcat(et.t0_t1); 
et_t0_t1 = vertcat(et_t0_t1{:,idx_exp_global_time});
et_t0_t1 = datetime(et_t0_t1,'ConvertFrom','datenum');

% Create a new ndi.element.timeseries object if one does not already exist
if isempty(e)
    elem_out = ndi.element.timeseries(D, name_out, reference_out,...
        ndi_element_timeseries_obj_in.type,...
        ndi_element_timeseries_obj_in,...
        false); % not direct
    data = [];
    time_global = [];
    epoch_i = 1:numel(et);
else
    % If one does exist, find missing epochs using global exp time
    elem_out = e{1};
    oneepoch_t0 = elem_out.epochtable.t0_t1{idx_exp_global_time}(1);
    oneepoch_t0 = datetime(oneepoch_t0,'ConvertFrom','datenum');
    [data,time] = elem_out.readtimeseries(1,-inf,inf);
    time_global = oneepoch_t0 + seconds(time);
    missing = false(size(et));
    for i = 1:numel(et)
        missing(i) = ~any(time_global >= et_t0_t1(i,1) & time_global <= et_t0_t1(i,2));
    end
    if ~any(missing)
        return
    end
    epoch_i = find(missing);

end

% Get data from all new epochs
for i = epoch_i
    mylog.msg('system',5,...
        ['Working on new element ' name_out ' : ' int2str(reference_out) ...
        ', subepoch ' int2str(i) ' of ' int2str(numel(et)) '.']);    
    [d,t] = ndi_element_timeseries_obj_in.readtimeseries(i,-inf,inf);
    time_global = cat(1,time_global,et_t0_t1(i,1) + seconds(t(:)));
    data = cat(1,data,d);
end

% Check that all time points are in order, if not, sort
[time_global,sortOrder] = sort(time_global);
if ~all(diff(sortOrder) == 1)
    data = data(sortOrder);
end

% Convert time
time = seconds(time_global - time_global(1));
t0 = time([1,end]);
t1 = convertTo(time_global([1,end]),'datenum');
ecs = arrayfun(@(k) et(1).epoch_clock{k}.type,1:numel(et(1).epoch_clock),'UniformOutput',false);

epoch_id = ['whole_session_' ndi_element_timeseries_obj_in.session.reference];

% Remove old doc from database
doc_old = ndi.database.fun.finddocs(D,elem_out.id(),epoch_id,'element_epoch');
if ~isempty(doc_old)
    D.database_rm(doc_old);
end

% Add new oneepoch to database
[elem_out,epochdoc] = elem_out.addepoch(epoch_id,...
    strjoin(ecs,','), [t0,t1], time, data);
D.database_add(epochdoc);