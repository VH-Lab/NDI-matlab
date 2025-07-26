function elem_out = downsample(D, ndi_element_timeseries_obj_in, LP, name_out, reference_out)
%NDI.ELEMENT.DOWNSAMPLE - Downsamples an ndi.element.timeseries object, applying anti-aliasing
%
%   ELEM_OUT = NDI.ELEMENT.DOWNSAMPLE(D, NDI_ELEMENT_TIMESERIES_OBJ_IN, LP, NAME_OUT, REFERENCE_OUT)
%
%   Downsamples the ndi.element.timeseries object NDI_ELEMENT_TIMESERIES_OBJ_IN
%   and creates a new ndi.element.timeseries object ELEM_OUT. The new object
%   will have the name NAME_OUT and reference REFERENCE_OUT. The original
%   object will not be modified. If the downsampled timeseries object
%   ELEM_OUT already exists, any new epochs will be downsampled and appended.
%
%   Inputs:
%       D - The ndi.dataset or ndi.session object containing the data.
%       NDI_ELEMENT_TIMESERIES_OBJ_IN - The ndi.element.timeseries object
%                                       to downsample.
%       LP - The low-pass frequency (in Hz) to use for downsampling.
%       NAME_OUT - The name of the new ndi.element.timeseries object.
%       REFERENCE_OUT - The reference number of the new
%                      ndi.element.timeseries object.
%
%   Outputs:
%       ELEM_OUT - The new downsampled ndi.element.timeseries object.
%
%   See also: DOWNSAMPLETIMESERIES, NDI.ELEMENT.TIMESERIES

% Validate inputs
arguments
    D {mustBeA(D, ["ndi.session", "ndi.dataset"])}
    ndi_element_timeseries_obj_in (1,1) {mustBeA(ndi_element_timeseries_obj_in, ["ndi.probe.timeseries", "ndi.element.timeseries"])} 
    LP (1,1) double {mustBePositive}
    name_out (1,:) char
    reference_out (1,1) double {mustBeNonnegative}
end

mylog = ndi.common.getLogger();

e = D.getelements('element.name',name_out,'element.reference',reference_out);

if isempty(e)
    % Create a new ndi.element.timeseries object if one does not already exist
    elem_out = ndi.element.timeseries(D, name_out, reference_out,...
        ndi_element_timeseries_obj_in.type,...
        ndi_element_timeseries_obj_in,...
        false); % not direct
else
    elem_out = e{1};
end

% Get epoch_ids for all missing elements
et = ndi_element_timeseries_obj_in.epochtable();
[missing,missing_ids] = ndi.element.missingepochs(et,elem_out.epochtable);
if ~missing
    disp(['All epochs of the element ' name_out ' | ' int2str(reference_out) ' have already been downsampled.'])
    return
end

% Loop over all not-yet downsampled epochs of the original object
for i = 1:numel(missing_ids)
    
    epoch_i = find(contains({et.epoch_id},missing_ids{i}));

    mylog.msg('system',5,...
        ['Working on new element ' name_out ' : ' int2str(reference_out) ...
        ', epoch ' int2str(epoch_i) ' of ' int2str(numel(et)) '.']);

    % Read the time series data for the current epoch
    [data, t] = ndi_element_timeseries_obj_in.readtimeseries(epoch_i,-inf,inf);

    %disp(['After reading: number of opened files: ' int2str(numel(openedFiles)) '.']);

    % Downsample the time series data
    t_down = downsample(t,LP);
    data_down = decimate(data,LP,'fir');

    % Get clock types and recalculate downsampled t0_t1 for each
    epoch_clocks = et(epoch_i).epoch_clock;
    ecs = cellfun(@(c) c.type,epoch_clocks,'UniformOutput',false);
    t0_t1 = zeros(numel(epoch_clocks),2);
    for k = 1:numel(epoch_clocks)
        t0_t1(1,k) = et(epoch_i).t0_t1{k}(1);
        if ndi.time.clocktype.isGlobal(epoch_clocks{k})
            t0_t1(2,k) = t0_t1(1,k) + t_down(end)/(24*60*60);
        else
            t0_t1(2,k) = t_down(end);
        end
    end
    
    % Add the downsampled data to the new object
    elem_out.addepoch(ndi_element_timeseries_obj_in.epochid(epoch_i),...
        strjoin(ecs,','),t0_t1, t_down, data_down);
    %disp(['After adding epoch ' int2str(i) ': number of opened files: ' int2str(numel(openedFiles)) '.']);    
end
