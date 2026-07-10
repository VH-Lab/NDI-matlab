function h = plot(varargin)
% ndi.fun.ensemble.plot - draw a spike raster of an ensemble
%
% H = ndi.fun.ensemble.PLOT(E, ...)
% H = ndi.fun.ensemble.PLOT(S, ENSEMBLEELEMENT, EPOCH, ...)
%
% Draws an ensemble as a spike raster in the current axes (gca), as a single
% line object. There are two ways to provide the data:
%
%   ndi.fun.ensemble.plot(E, ...)
%       E is an ensemble structure from ndi.fun.ensemble.read (optionally passed
%       through ndi.fun.ensemble.filter first). The raster is drawn from
%       E.activity, so you can filter before plotting.
%
%   ndi.fun.ensemble.plot(S, ENSEMBLEELEMENT, EPOCH, ...)
%       Convenience form: reads EPOCH of ENSEMBLEELEMENT (an ndi.element.ensemble
%       or its document / id) from session S and plots the whole (unfiltered)
%       ensemble.
%
% Each neuron ("cell") i (the row index in E.activity) is drawn as a horizontal
% band of tick marks: every spike is a short vertical line at the spike time (X
% axis) spanning the vertical interval [BottomEdge, TopEdge] + i*Offset on the Y
% axis. With the defaults (0.1, 0.9, 1.0), cell 1 occupies 1.1 to 1.9, cell 2
% occupies 2.1 to 2.9, and so on.
%
% The entire raster is one line object: the tick coordinates are concatenated
% with a NaN separating successive ticks (a spike at time t of cell i
% contributes (t, bottom_i), (t, top_i), (NaN, NaN)). One line keeps the initial
% plot and any redraw (setting H.XData / H.YData) fast for large ensembles.
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   BottomEdge (0.1)   - distance from a cell's baseline to the bottom of its
%                        tick marks.
%   TopEdge (0.9)      - distance from a cell's baseline to the top of its ticks.
%   Offset (1.0)       - spacing between successive cells along the Y axis.
%   Color ([0 0 0])    - color of the tick marks (RGB triplet or color name).
%   LineWidth (0.75)   - width of the tick-mark lines, in points.
%   XLabel (true)      - if true, label the X axis 'Time(s)'.
%   YLabel (true)      - if true, label the Y axis 'Neuron #'.
%
% =========================================================================
% OUTPUT
% =========================================================================
%   H - the handle to the single line object that draws the raster.
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   E = ndi.fun.ensemble.read(S, ens, 'epoch_1', 'MinQuality', 2);
%   figure; ndi.fun.ensemble.plot(E);
%
% See also: ndi.fun.ensemble.read, ndi.fun.ensemble.filter, LINE

    if isempty(varargin)
        error('ndi:ensemble:plot:badInput', ...
            ['Call as ndi.fun.ensemble.plot(E, ...) with an ensemble structure, ' ...
            'or ndi.fun.ensemble.plot(S, ENSEMBLEELEMENT, EPOCH, ...).']);
    end
    if isstruct(varargin{1})
        E = varargin{1};
        nvpairs = varargin(2:end);
    elseif numel(varargin) >= 3
        E = ndi.fun.ensemble.read(varargin{1}, varargin{2}, varargin{3});
        nvpairs = varargin(4:end);
    else
        error('ndi:ensemble:plot:badInput', ...
            ['Call as ndi.fun.ensemble.plot(E, ...) with an ensemble structure, ' ...
            'or ndi.fun.ensemble.plot(S, ENSEMBLEELEMENT, EPOCH, ...).']);
    end

    h = local_draw(E, nvpairs{:});

end % plot()

% -------------------------------------------------------------------------

function h = local_draw(E, options)
    arguments
        E struct
        options.BottomEdge (1,1) double = 0.1
        options.TopEdge (1,1) double = 0.9
        options.Offset (1,1) double = 1.0
        options.Color = [0 0 0]
        options.LineWidth (1,1) double {mustBePositive} = 0.75
        options.XLabel (1,1) logical = true
        options.YLabel (1,1) logical = true
    end

    % find() on the (sparse) activity matrix returns each spike's row (the
    % cell/neuron index) and its value (the spike time).
    [cellIndex, ~, spikeTime] = find(E.activity);
    cellIndex = cellIndex(:).';
    spikeTime = spikeTime(:).';
    nSpikes = numel(spikeTime);

    X = nan(1, 3*nSpikes);
    Y = nan(1, 3*nSpikes);
    X(1:3:end) = spikeTime;
    X(2:3:end) = spikeTime;
    Y(1:3:end) = options.BottomEdge + cellIndex * options.Offset;
    Y(2:3:end) = options.TopEdge    + cellIndex * options.Offset;

    ax = gca;
    h = line(ax, X, Y, 'Color', options.Color, 'LineWidth', options.LineWidth);

    if options.XLabel
        xlabel(ax, 'Time(s)');
    end
    if options.YLabel
        ylabel(ax, 'Neuron #');
    end

end % local_draw()
