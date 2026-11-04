function epochIndex = matchCellIntervalsToEpochs(cellIntervals, epochIntervals)
% MATCHCELLINTERVALSTOEPOCHS - Pair a legacy cell's recording intervals with epochs.
%
% EPOCHINDEX = ndi.setup.conv.vhlab.matchCellIntervalsToEpochs(CELLINTERVALS, EPOCHINTERVALS)
%
% CELLINTERVALS is the N x 2 list of [start end] intervals stored with a legacy
% cell (get_intervals). EPOCHINTERVALS is the M x 2 list of [start end]
% intervals of the probe's epochs, recomputed from each epoch directory's
% stims.mat and stimtimes.txt. EPOCHINDEX is N x 1: the row of EPOCHINTERVALS
% paired with each cell interval, or NaN if none is.
%
% The two lists need not agree exactly. A cell's intervals were saved by the
% legacy code of their day, which can differ from today's recomputation in
% the last digits of the start time or in the padding added to the end. Each
% cell interval is paired with the epoch it overlaps most, provided that
% overlap covers more than half of the shorter of the two intervals. Each
% epoch is paired at most once; if two cell intervals would claim the same
% epoch, the one with the larger overlap keeps it.
%
% Example:
%   matchCellIntervalsToEpochs([0 10; 20.0004 31], [0 10.5; 20 30])  % returns [1; 2]
%
% See also: ndi.setup.conv.vhlab.importMeasuredDataCells

    arguments
        cellIntervals (:,2) double
        epochIntervals (:,2) double
    end

    n = size(cellIntervals, 1);
    epochIndex = nan(n, 1);
    bestOverlap = zeros(n, 1);
    for j = 1:n
        overlap = min(cellIntervals(j,2), epochIntervals(:,2)) - max(cellIntervals(j,1), epochIntervals(:,1));
        shorter = min(diff(cellIntervals(j,:)), diff(epochIntervals, 1, 2));
        ok = overlap > 0.5 * shorter;
        if any(ok)
            overlap(~ok) = -Inf;
            [bestOverlap(j), epochIndex(j)] = max(overlap);
        end
    end

    % each epoch at most once: keep the cell interval that overlaps it most
    for k = unique(epochIndex(~isnan(epochIndex)))'
        claim = find(epochIndex == k);
        if numel(claim) > 1
            [~, keep] = max(bestOverlap(claim));
            epochIndex(claim([1:keep-1, keep+1:end])) = NaN;
        end
    end
end
