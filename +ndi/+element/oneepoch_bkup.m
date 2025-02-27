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

if ~isempty(e), D.database_rm(e{1}.id()); e = []; end;

assert(isempty(e),['Element with name ' name_out ' and reference ' int2str(reference_out) ' already exists. Delete it before making a new one.']);

% Create the new ndi.element.timeseries object
elem_out = ndi.element.timeseries(D, name_out, reference_out,...
    ndi_element_timeseries_obj_in.type,...
    ndi_element_timeseries_obj_in,...
    false); % not direct

% Get the epoch table
et = ndi_element_timeseries_obj_in.epochtable();

globalClocks = {'utc','approx_utc','exp_global_time','approx_exp_global_time','dev_global_time','approx_dev_global_time'};

match = -inf;
epochTest = 1;

for i=1:numel(globalClocks)
    % TODO: this is a kludge, really need to allow ndi.element.add_epoch to add more than one clock
    % bug here
    tr = ndi.time.timereference(ndi_element_timeseries_obj_in,ndi.time.clocktype('dev_local_time'),epochTest,0);
    [t_out]=D.syncgraph.time_convert(tr,0,ndi_element_timeseries_obj_in.underlying_element,ndi.time.clocktype(globalClocks{i}));
    if ~isempty(t_out)
        match = i;
        break;
    end;
end

if match>0
    isGlobal = 1;
    clockTarget = ndi.time.clocktype(globalClocks{match});
else
    isGlobal = 0;
    clockTarget = ndi.time.clocktype('dev_local_time');
end

data = [];
time = [];

et2 = ndi_element_timeseries_obj_in.underlying_element.epochtable();

idx = find(cellfun(@(x) eq(clockTarget,x),et2(1).epoch_clock));
t0_t1_begin = et2(1).t0_t1{idx};
idx = find(cellfun(@(x) eq(clockTarget,x),et2(end).epoch_clock));
t0_t1_end = et2(end).t0_t1{idx};



nextTime = 0;


t0_t1_local = [];
nextLocalTime = 0;

for i=1:numel(et)
    mylog.msg('system',5,...
        ['Working on new element ' name_out ' : ' int2str(reference_out) ...
        ', subepoch ' int2str(i) ' of ' int2str(numel(et)) '.']);    
    [d,t] = ndi_element_timeseries_obj_in.readtimeseries(i,-inf,inf);
    idx = find(cellfun(@(x) eq(ndi.time.clocktype('dev_local_time'),x),et(i).epoch_clock));
    if i==1
        t0_t1_local(1) = et(i).t0_t1{idx}(1);
    end
    nextLocalTime = nextLocalTime + et(i).t0_t1{idx}(2) - et(i).t0_t1{idx}(1);
    t0_t1_local(2) = nextLocalTime;

%    if isGlobal
%        tr = ndi.time.timereference(ndi_element_timeseries_obj_in,ndi.time.clocktype('dev_local_time'),i,0);
%        t = D.syncgraph.time_convert(tr,t,ndi_element_timeseries_obj_in.underlying_element,clockTarget);
%        time = cat(1,time,t(:));
%    else
        time = cat(1,time,nextTime + t(:));
        nextTime = nextTime + t(end)+t(2)-t(1);
%    end
    data = cat(1,data,d);
end

ecs = {'dev_local_time'};
t0_t1 = [t0_t1_local(:)];

if isGlobal,
    ecs{end+1} = clockTarget.type;
    tr = ndi.time.timereference(ndi_element_timeseries_obj_in,ndi.time.clocktype('dev_local_time'),1,0);
    t0 = D.syncgraph.time_convert(tr,et(1).t0_t1{idx}(1),ndi_element_timeseries_obj_in.underlying_element,clockTarget);
    tr = ndi.time.timereference(ndi_element_timeseries_obj_in,ndi.time.clocktype('dev_local_time'),numel(et),0); % idx should still be valid
    t1 = D.syncgraph.time_convert(tr,et(end).t0_t1{idx}(2),ndi_element_timeseries_obj_in.underlying_element,clockTarget);
    t0_t1(:,end+1) = [t0 t1]';
end
epoch_id = ['whole_session_' ndi_element_timeseries_obj_in.session.reference];

[elem_out,epochdoc] = elem_out.addepoch(epoch_id,...
        strjoin(ecs,','), t0_t1, t, d);


D.database_add(epochdoc);
