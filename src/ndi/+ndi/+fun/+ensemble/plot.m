function h = plot(S, ensemble_doc, options)
% ndi.fun.ensemble.plot - draw a spike raster of an ensemble document
%
% H = ndi.fun.ensemble.PLOT(S, ENSEMBLE_DOC, ...)
%
% Reads the ensemble activity stored in the 'ensemble' ndi.document
% ENSEMBLE_DOC (belonging to the ndi.session or ndi.dataset S) and draws it as a
% spike raster in the current axes (gca). Each neuron ("cell") of the ensemble
% is drawn as a horizontal band of tick marks: every spike is a short vertical
% line placed at the spike time (X axis) and spanning a fixed vertical interval
% for that cell (Y axis).
%
% For cell i (i = 1..N, the row index of the ensemble activity matrix), the tick
% marks span the vertical interval
%
%       [ BottomEdge , TopEdge ] + i * Offset
%
% so with the default BottomEdge = 0.1, TopEdge = 0.9, and Offset = 1.0, cell 1
% occupies 1.1 to 1.9, cell 2 occupies 2.1 to 2.9, and so on: each cell sits in
% its own unit-height row with a 0.1 gap above and below.
%
% The entire raster is drawn as a SINGLE line object. The coordinates of every
% tick are concatenated into one pair of X/Y vectors, with a NaN separating
% successive ticks so that the line is broken between them (a spike at time t of
% cell i contributes the points (t, bottom_i), (t, top_i), (NaN, NaN)). Drawing
% one line rather than one object per spike makes both the initial plot and any
% later redraw (e.g. setting H.XData / H.YData) fast, even for large ensembles.
%
% =========================================================================
% INPUTS
% =========================================================================
%   S            - the ndi.session or ndi.dataset that ENSEMBLE_DOC belongs to
%                  (needed to read the document's binary activity file).
%   ENSEMBLE_DOC - an 'ensemble' ndi.document (as produced by
%                  ndi.fun.ensemble.create).
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   BottomEdge (0.1)   - vertical distance from a cell's integer baseline to the
%                        bottom of its tick marks.
%   TopEdge (0.9)      - vertical distance from a cell's integer baseline to the
%                        top of its tick marks.
%   Offset (1.0)       - spacing between successive cells along the Y axis (the
%                        multiplier applied to the cell index).
%   Color ([0 0 0])    - color of the tick marks; any valid MATLAB color
%                        specification (RGB triplet or color name). Default black.
%   LineWidth (0.75)   - width of the tick-mark lines, in points.
%   XLabel (true)      - if true, label the X axis 'Time(s)'.
%   YLabel (true)      - if true, label the Y axis 'Neuron #'.
%
% =========================================================================
% OUTPUT
% =========================================================================
%   H - the handle to the single line object that draws the raster. Its XData
%       and YData can be reassigned to redraw the raster in place.
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   docs = S.database_search(ndi.query('','isa','ensemble',''));
%   figure;
%   ndi.fun.ensemble.plot(S, docs{1});
%
%   % overlay two ensembles in different colors in the same axes:
%   figure; hold on;
%   ndi.fun.ensemble.plot(S, docsA, 'Color', [0 0 0]);
%   ndi.fun.ensemble.plot(S, docsB, 'Color', [0.85 0 0]);
%
% See also: ndi.fun.ensemble.read, ndi.fun.ensemble.create, LINE

    arguments
        S
        ensemble_doc (1,1) ndi.document
        options.BottomEdge (1,1) double = 0.1
        options.TopEdge (1,1) double = 0.9
        options.Offset (1,1) double = 1.0
        options.Color = [0 0 0]
        options.LineWidth (1,1) double {mustBePositive} = 0.75
        options.XLabel (1,1) logical = true
        options.YLabel (1,1) logical = true
    end

    % --- read the ensemble activity ---------------------------------------
    activity = ndi.fun.ensemble.read(S, ensemble_doc);
    if ~issparse(activity) && ~isnumeric(activity)
        error('ndi:ensemble:plot:notMatrix', ...
            ['ndi.fun.ensemble.plot only supports 2-D (neuron-by-spike) ' ...
            'ensembles; this document stores a %d-dimensional array.'], ...
            numel(activity.size));
    end

    % --- assemble the tick-mark coordinates for a single line -------------
    % find() on the sparse matrix returns, for every stored spike, its row
    % (the cell/neuron index) and its value (the spike time).
    [cellIndex, ~, spikeTime] = find(activity);
    cellIndex = cellIndex(:).';
    spikeTime = spikeTime(:).';
    nSpikes = numel(spikeTime);

    X = nan(1, 3*nSpikes);
    Y = nan(1, 3*nSpikes);
    % positions 1 and 2 of each triple are the bottom and top of the tick; the
    % third stays NaN to break the line before the next tick.
    X(1:3:end) = spikeTime;
    X(2:3:end) = spikeTime;
    Y(1:3:end) = options.BottomEdge + cellIndex * options.Offset;
    Y(2:3:end) = options.TopEdge    + cellIndex * options.Offset;

    % --- draw into the current axes as one line ---------------------------
    ax = gca;
    h = line(ax, X, Y, 'Color', options.Color, 'LineWidth', options.LineWidth);

    if options.XLabel
        xlabel(ax, 'Time(s)');
    end
    if options.YLabel
        ylabel(ax, 'Neuron #');
    end

end % plot()
