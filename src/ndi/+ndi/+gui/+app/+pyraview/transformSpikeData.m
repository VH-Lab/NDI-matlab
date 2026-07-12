function [X, Y] = transformSpikeData(spiking_info, selectedIdx, t0, t1, spacing, show_box)
% TRANSFORM_SPIKE_DATA - Prepare spike data for plotting
%
%   [X, Y] = ndi.gui.app.pyraview.transformSpikeData(SPIKING_INFO, SELECTEDIDX, T0, T1, SPACING, SHOW_BOX)
%
%   Inputs:
%       SPIKING_INFO - Struct array from load_spiking_neurons
%       SELECTEDIDX  - Indices of spiking_info to plot
%       T0           - Start time of view
%       T1           - End time of view
%       SPACING      - Vertical spacing between channels
%       SHOW_BOX     - (Optional, default false) If true, also emit a 2 ms wide
%                      box outline per spike spanning from the unit's
%                      'low_channel' to its 'high_channel' (same line, so it
%                      can be drawn in one plot call per color).
%
%   Outputs:
%       X, Y         - Vectors for plotting (NaN-separated segments)
%

    arguments
        spiking_info struct
        selectedIdx (1,:) double
        t0 (1,1) double
        t1 (1,1) double
        spacing (1,1) double
        show_box (1,1) logical = false
    end

    X = [];
    Y = [];

    if isempty(spiking_info) || isempty(selectedIdx)
        return;
    end

    box_half_width = 0.001; % seconds; box is 2 ms wide, centered on the spike

    x_cells = {};
    y_cells = {};

    for k = 1:numel(selectedIdx)
        idx = selectedIdx(k);
        if idx > numel(spiking_info), continue; end

        info = spiking_info(idx);
        times = info.spike_times;

        % Use best_channel instead of center_of_mass
        if isfield(info, 'best_channel')
            ch_idx = info.best_channel;
        elseif isfield(info, 'center_of_mass')
            ch_idx = round(info.center_of_mass);
        else
            ch_idx = 1;
        end

        if isempty(times), continue; end

        % Filter times within view. Only spikes inside [t0, t1] are visible,
        % so restricting to the window keeps the number of plotted segments
        % proportional to what is on screen rather than the whole epoch.
        t_plot = times(times >= t0 & times <= t1);

        if isempty(t_plot), continue; end

        % Calculate Y positions
        % (ch_idx-1)*S + 0.4*S to +0.6*S
        y_base = (ch_idx - 1) * spacing;
        y1 = y_base + 0.4 * spacing;
        y2 = y_base + 0.6 * spacing;

        numSpikes = numel(t_plot);
        tr = t_plot(:)'; % row vector of spike times

        % Construct vertical tick segments: (t, y1) -> (t, y2) -> (NaN, NaN)
        tempX = [tr; tr; nan(1, numSpikes)];
        tempY = [repmat(y1, 1, numSpikes); repmat(y2, 1, numSpikes); nan(1, numSpikes)];

        x_cells{end+1} = tempX(:); %#ok<AGROW>
        y_cells{end+1} = tempY(:); %#ok<AGROW>

        % Optional box spanning the significant-channel extent of the unit.
        if show_box
            if isfield(info, 'low_channel') && ~isempty(info.low_channel)
                lo = info.low_channel;
            else
                lo = ch_idx;
            end
            if isfield(info, 'high_channel') && ~isempty(info.high_channel)
                hi = info.high_channel;
            else
                hi = ch_idx;
            end

            yLow = (lo - 1) * spacing;
            yHigh = (hi - 1) * spacing;

            xL = tr - box_half_width;
            xR = tr + box_half_width;

            % Rectangle outline per spike, NaN-separated:
            % (xL,yLow)->(xR,yLow)->(xR,yHigh)->(xL,yHigh)->(xL,yLow)->NaN
            boxX = [xL; xR; xR; xL; xL; nan(1, numSpikes)];
            boxY = [repmat(yLow, 1, numSpikes); repmat(yLow, 1, numSpikes); ...
                    repmat(yHigh, 1, numSpikes); repmat(yHigh, 1, numSpikes); ...
                    repmat(yLow, 1, numSpikes); nan(1, numSpikes)];

            x_cells{end+1} = boxX(:); %#ok<AGROW>
            y_cells{end+1} = boxY(:); %#ok<AGROW>
        end
    end

    if ~isempty(x_cells)
        X = cell2mat(x_cells');
        Y = cell2mat(y_cells');
    end
end
