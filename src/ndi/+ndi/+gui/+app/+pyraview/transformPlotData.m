function [X, Y] = transformPlotData(data, tVec, level, spacing, mapping)
% TRANSFORM_PLOT_DATA - Prepare data for efficient multi-channel plotting
%
%   [X, Y] = ndi.gui.app.pyraview.transformPlotData(DATA, TVEC, LEVEL, SPACING, MAPPING)
%
%   Inputs:
%       DATA    - Data matrix (Samples x Channels) or (Samples x Channels x 2).
%       TVEC    - Time vector (Samples x 1).
%       LEVEL   - Decimation level (0 for raw, >0 for decimated).
%       SPACING - Vertical spacing between channels.
%       MAPPING - (Optional) Channel mapping vector.
%
%   Outputs:
%       X       - X-coordinates for plotting (single vector with NaNs).
%       Y       - Y-coordinates for plotting (single vector with NaNs).
%

    arguments
        data double
        tVec (:,1) double
        level (1,1) double
        spacing (1,1) double
        mapping (1,:) double = []
    end

    if isempty(data)
        X = [];
        Y = [];
        return;
    end

    % Apply mapping if provided
    if ~isempty(mapping)
        try
            data = data(:, mapping, :);
        catch
            warning('Failed to apply mapping in transformPlotData. Using raw channel order.');
        end
    end

    numSamples = size(data, 1);
    numChannels = size(data, 2);

    if level == 0
        % Raw Data: Samples x Channels
        % Construct single X and Y vectors
        % Y: data(:,c) + (c-1)*spacing
        % Separate channels with NaN

        totalPoints = numChannels * (numSamples + 1);
        X = NaN(totalPoints, 1);
        Y = NaN(totalPoints, 1);

        for c = 1:numChannels
            offset = (c-1) * spacing;
            startIdx = (c-1) * (numSamples + 1) + 1;
            endIdx = startIdx + numSamples - 1;

            X(startIdx:endIdx) = tVec;
            Y(startIdx:endIdx) = data(:, c) + offset;

            % The next point (endIdx+1) is already NaN by initialization
        end

    else
        % Decimated Data: Samples x Channels x 2
        % Construct single X and Y vectors for vertical bars
        % For each sample i, channel c: (t(i), min), (t(i), max), (NaN, NaN)
        % This creates 3 points per sample per channel.

        pointsPerSample = 3;
        totalPoints = numSamples * pointsPerSample * numChannels;

        X = NaN(totalPoints, 1);
        Y = NaN(totalPoints, 1);

        for c = 1:numChannels
            offset = (c-1) * spacing;

            mins = data(:, c, 1) + offset;
            maxs = data(:, c, 2) + offset;

            tempY = [mins'; maxs'; nan(1, numSamples)];
            tempX = [tVec'; tVec'; nan(1, numSamples)];

            colY = tempY(:);
            colX = tempX(:);

            startIdx = (c-1) * numel(colY) + 1;
            endIdx = startIdx + numel(colY) - 1;

            X(startIdx:endIdx) = colX;
            Y(startIdx:endIdx) = colY;
        end
    end
end
