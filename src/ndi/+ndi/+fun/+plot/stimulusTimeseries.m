function [h, htext] = stimulusTimeseries(timeref, y, options)
% NDI.FUN.PLOT.STIMULUSTIMESERIES - plot the occurence of a stimulus or stimuli as a thick bar on a time series plot
%
% [H, HTEXT] = NDI.FUN.PLOT.STIMULUSTIMESERIES(TIMEREF, Y, ...)
%
% Plots a stimulus time series based on an NDI time reference.
%
% Inputs:
%   TIMEREF - an ndi.time.timereference object that refers to the stimulus probe.
%             To create a timeref from an epoch of a stimulator:
%                timeref = ndi.time.timereference(stim_probe, ndi.time.clocktype('dev_local_time'), epoch_id, 0);
%             where stim_probe is the ndi.probe object for the stimulator, and epoch_id is the epoch identifier or number.
%   Y       - the y-coordinate to plot the stimulus bars
%
% Name/Value pairs:
%   'stimid' ([])                        - Stimulus ID numbers for each entry; if present, will be plotted.
%                                          If empty or not provided, the function attempts to read 'stimid' from the probe data.
%   'linewidth' (2)                      - Line size
%   'linecolor' ([0 0 0])                - Line color
%   'FontSize' (12)                      - Font size for text (if 'stimid' is present)
%   'FontWeight' ('normal')              - Font weight
%   'FontColor' ([0 0 0])                - Text default color
%   'textycoord' ([])                    - Text y coordinate. If empty, defaults to Y+1.
%   'HorizontalAlignment' ('center')     - Text horizontal alignment
%
% Example:
%   % Create a time reference for the first epoch of a probe
%   timeref = ndi.time.timereference(my_probe, ndi.time.clocktype('dev_local_time'), 1, 0);
%
%   % Plot the stimulus timeseries at y=0
%   figure;
%   ndi.fun.plot.stimulusTimeseries(timeref, 0);
%
% See also: vlt.neuro.stimulus.plot_stimulus_timeseries, ndi.time.timereference

    arguments
        timeref (1,1) ndi.time.timereference
        y (1,1) double
        options.stimid = []
        options.linewidth (1,1) double = 2
        options.linecolor (1,3) double = [0 0 0]
        options.FontSize (1,1) double = 12
        options.FontWeight (1,:) char = 'normal'
        options.FontColor (1,3) double = [0 0 0]
        options.textycoord (:,:) double = []
        options.HorizontalAlignment (1,:) char = 'center'
    end

    probe = timeref.referent;

    % Read the stimulus data
    [data, t, ~] = probe.readtimeseries(timeref, -Inf, Inf);

    % Handle stimid
    stimid = options.stimid;

    if isempty(stimid) && isfield(data, 'stimid')
        stimid = data.stimid;
    end

    % Prepare arguments for vlt.neuro.stimulus.plot_stimulus_timeseries
    vlt_args = {};
    if ~isempty(stimid)
        vlt_args = [vlt_args, {'stimid', stimid}];
    end

    vlt_args = [vlt_args, {'linewidth', options.linewidth}];
    vlt_args = [vlt_args, {'linecolor', options.linecolor}];
    vlt_args = [vlt_args, {'FontSize', options.FontSize}];
    vlt_args = [vlt_args, {'FontWeight', options.FontWeight}];
    vlt_args = [vlt_args, {'FontColor', options.FontColor}];
    vlt_args = [vlt_args, {'HorizontalAlignment', options.HorizontalAlignment}];

    if ~isempty(options.textycoord)
        vlt_args = [vlt_args, {'textycoord', options.textycoord}];
    end

    % Call the plotting function
    % Check if t has stimon and stimoff fields
    if ~isfield(t, 'stimon') || ~isfield(t, 'stimoff')
        error('The time structure returned by readtimeseries does not contain stimon and stimoff fields.');
    end

    [h, htext] = vlt.neuro.stimulus.plot_stimulus_timeseries(y, t.stimon, t.stimoff, vlt_args{:});
end
