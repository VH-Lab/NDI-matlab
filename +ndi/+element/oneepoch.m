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

% Get the element and associated epoch table
e = D.getelements('element.name',name_out,'element.reference',reference_out);
element_exists = ~isempty(e);
epoch_id = ['whole_session_' ndi_element_timeseries_obj_in.session.reference];
et = ndi_element_timeseries_obj_in.epochtable();
t0_t1_in = vertcat(et.t0_t1);
epoch_ids = {et.epoch_id};

% Check if there is a global clock, if not, use dev_local_time
epoch_clocks = et(1).epoch_clock;
ecs = cellfun(@(c) c.type,epoch_clocks,'UniformOutput',false);
clock_ind = find(cellfun(@(x) ndi.time.clocktype.isGlobal(x),epoch_clocks),1);
if isempty(clock_ind)
    clock_ind = find(contains(ecs,'dev_local_time'));
    clock_global = false;
    if isempty(clock_ind)
        error('No global or local clock found in this elements epochtable.')
    end
else
    clock_global = true;
end

% Create a new ndi.element.timeseries object if one does not already exist
if ~element_exists
    elem_out = ndi.element.timeseries(D, name_out, reference_out,...
        ndi_element_timeseries_obj_in.type,ndi_element_timeseries_obj_in,false);
    time = [];
    data = [];
    new_epochs = 1:numel(et);
else
    % If one does exist, read the data
    elem_out = e{1};
    [data,time] = elem_out.readtimeseries(1,-inf,inf);
    if clock_global
        epoch_t0 = e{1}.epochtable.t0_t1{clock_ind}(1);
        time = epoch_t0 + time/(24*60*60);
    end

    % Compare existing epoch ids with current ones
    epochdoc = ndi.database.fun.finddocs(D,elem_out.id(),epoch_id,'oneepoch');
    oneepoch_ids = split(epochdoc{1}.document_properties.oneepoch.epoch_ids,',');
    new_epochs = find(~contains(epoch_ids,oneepoch_ids));
end

% Get data from all new epochs
for i = new_epochs
    mylog.msg('system',5,...
        ['Working on new element ' name_out ' : ' int2str(reference_out) ...
        ', subepoch ' int2str(i) ' of ' int2str(numel(et)) '.']);    
    [d,t] = ndi_element_timeseries_obj_in.readtimeseries(i,-inf,inf);
    if clock_global
        epoch_t0 = t0_t1_in{i,clock_ind}(1);
        t = epoch_t0 + t/(24*60*60);
    elseif ~clock_global & ~isempty(time)
        t = time(end) + t(2)-t(1) + t(:);
    end
    time = cat(1,time,t(:));
    data = cat(1,data,d);
end

% Check that all time points are in order and convert to local time
if clock_global
    [time,sortOrder] = sort(time);
    if ~all(diff(sortOrder) == 1)
        data = data(sortOrder);
    end
    time = 24*60*60*(time - time(1));
end

% Retrieve t0_t1 for each clock type
t0_t1 = zeros(numel(epoch_clocks),2);
for k = 1:numel(epoch_clocks)
    t0_t1(1,k) = t0_t1_in{1,k}(1);
    if ndi.time.clocktype.isGlobal(epoch_clocks{k})
        t0_t1(2,k) = t0_t1(1,k) + time(end)/(24*60*60);
    else
        t0_t1(2,k) = time(end);
    end
end

% Add oneepoch to database
if element_exists
    D.database_rm(epochdoc);
end

[elem_out,epochdoc] = elem_out.addepoch(epoch_id,...
    strjoin(ecs,','), t0_t1, time, data, strjoin(epoch_ids,','));
D.database_add(epochdoc);