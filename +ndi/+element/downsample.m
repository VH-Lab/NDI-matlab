function elem_out = downsample(D, ndi_element_timeseries_obj_in, LP, name_out, reference_out)
%NDI.ELEMENT.DOWNSAMPLE - Downsamples an ndi.element.timeseries object, applying anti-aliasing
%
%   ELEM_OUT = NDI.ELEMENT.DOWNSAMPLE(D, NDI_ELEMENT_TIMESERIES_OBJ_IN, LP, NAME_OUT, REFERENCE_OUT)
%
%   Downsamples the ndi.element.timeseries object NDI_ELEMENT_TIMESERIES_OBJ_IN
%   and creates a new ndi.element.timeseries object ELEM_OUT. The new object
%   will have the name NAME_OUT and reference REFERENCE_OUT. The original
%   object will not be modified.
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

 % first check to see if it already exists

e = D.getelements('element.name',name_out,'element.reference',reference_out);

assert(isempty(e),['Element with name ' name_out ' and reference ' int2str(reference_out) ' already exists. Delete it before making a new one.']);

% Create the new ndi.element.timeseries object
elem_out = ndi.element.timeseries(D, name_out, reference_out,...
    ndi_element_timeseries_obj_in.type,...
    ndi_element_timeseries_obj_in,...
    false); % not direct

% Get the epoch table
et = ndi_element_timeseries_obj_in.epochtable();

% Loop over all epochs of the original object
for epoch_i = 1:numel(et)
    mylog.msg('system',5,...
        ['Working on new element ' name_out ' : ' int2str(reference_out) ...
        ', epoch ' int2str(epoch_i) ' of ' int2str(numel(et)) '.']);

    % Read the time series data for the current epoch
    [data, t] = ndi_element_timeseries_obj_in.readtimeseries(epoch_i,-inf,inf);

    % Downsample the time series data
    [t_down, data_down] = ndi.util.downsampleTimeseries(t, data, LP);
    % Find dev_local_time epoch

    epoch_clock_str = {};
    t0_t1 = [];
    for k = 1:numel(et(epoch_i).epoch_clock)
        epoch_clock_str{k} = et(epoch_i).epoch_clock{k}.type;
        t0_t1([1 2],k) = et(epoch_i).t0_t1{k}(:);
    end

    epoch_clock_str = strjoin(epoch_clock_str,',');

    % Add the downsampled data to the new object
    elem_out.addepoch(ndi_element_timeseries_obj_in.epochid(epoch_i),...
        epoch_clock_str,t0_t1, t_down, data_down);
end
