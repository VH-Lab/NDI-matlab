function h = plot(S, ensembleElement, epoch, options)
% ndi.fun.ensemble.plot - draw a spike raster of an ensemble element
%
% H = ndi.fun.ensemble.PLOT(S, ENSEMBLEELEMENT, EPOCH, ...)
%
% Reads epoch EPOCH of ENSEMBLEELEMENT (an ndi.element.ensemble, or its document
% / id, belonging to the ndi.session/ndi.dataset S) and draws it as a spike
% raster in the current axes (gca). Each neuron ("cell") of the ensemble is
% drawn as a horizontal band of tick marks: every spike is a short vertical line
% at the spike time (X axis) spanning a fixed vertical interval for that cell (Y
% axis).
%
% Because it reads through ENSEMBLEELEMENT.readtimeseries, an optional [T0 T1]
% window can be supplied to draw (and cheaply redraw) just part of the epoch.
%
% For cell i (the 1-based neuron column index returned by readtimeseries) the
% tick marks span the vertical interval
%
%       [ BottomEdge , TopEdge ] + i * Offset
%
% so with the defaults (0.1, 0.9, 1.0) cell 1 occupies 1.1 to 1.9, cell 2
% occupies 2.1 to 2.9, and so on.
%
% The entire raster is drawn as a SINGLE line object: the coordinates of every
% tick are concatenated into one pair of X/Y vectors, with a NaN separating
% successive ticks (a spike at time t of cell i contributes the points
% (t, bottom_i), (t, top_i), (NaN, NaN)). One line makes the initial plot and
% any later redraw (setting H.XData / H.YData) fast, even for large ensembles.
%
% =========================================================================
% INPUTS
% =========================================================================
%   S               - the ndi.session/ndi.dataset that ENSEMBLEELEMENT belongs to.
%   ENSEMBLEELEMENT - an ndi.element.ensemble (or its document / id).
%   EPOCH           - the epoch to plot (an epoch id or index).
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   T0 (-Inf)          - start of the time window to read/draw (element clock).
%   T1 (Inf)           - end of the time window to read/draw.
%   BottomEdge (0.1)   - vertical distance from a cell's baseline to the bottom
%                        of its tick marks.
%   TopEdge (0.9)      - vertical distance from a cell's baseline to the top of
%                        its tick marks.
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
%   ens = ndi.fun.ensemble.create(S, probe, 'epoch_1');
%   figure; ndi.fun.ensemble.plot(S, ens, 'epoch_1');
%
% See also: ndi.element.ensemble, ndi.fun.ensemble.read, LINE

    arguments
        S
        ensembleElement
        epoch
        options.T0 (1,1) double = -Inf
        options.T1 (1,1) double = Inf
        options.BottomEdge (1,1) double = 0.1
        options.TopEdge (1,1) double = 0.9
        options.Offset (1,1) double = 1.0
        options.Color = [0 0 0]
        options.LineWidth (1,1) double {mustBePositive} = 0.75
        options.XLabel (1,1) logical = true
        options.YLabel (1,1) logical = true
    end

    ens = local_ensemble(ensembleElement, S);

    % read the spikes as a marked point process: data = neuron column index,
    % t = spike time (windowed to [T0 T1]).
    [cellIndex, spikeTime] = ens.readtimeseries(epoch, options.T0, options.T1);
    cellIndex = round(cellIndex(:).');
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

end % plot()

% -------------------------------------------------------------------------

function ens = local_ensemble(x, S)
% return an ndi.element.ensemble from an object, a document, or an id
    if isa(x, 'ndi.element.ensemble')
        ens = x;
    else
        ens = ndi.database.fun.ndi_document2ndi_object(x, S);
        if ~isa(ens, 'ndi.element.ensemble')
            error('ndi:ensemble:plot:notEnsemble', ...
                'The provided element is not an ndi.element.ensemble.');
        end
    end
end % local_ensemble()
