function [levelIndex, levelRow] = chooseLevel(levels, targetVoxelSize)
% NDI.FUN.DOC.LIGHTSHEET.CHOOSELEVEL - pick the coarsest level meeting a target
%
%   [LEVELINDEX, LEVELROW] = NDI.FUN.DOC.LIGHTSHEET.CHOOSELEVEL(LEVELS,
%       TARGETVOXELSIZE)
%
%   Given LEVELS (a struct array or table with per-level `voxel_size`
%   and `level` fields, finest-first, e.g. from LEVELTABLE), returns
%   the coarsest level whose per-axis voxel size is still <=
%   TARGETVOXELSIZE. If every level is coarser than the target, returns
%   level 0. If every level is finer, returns the coarsest.
%
%   LEVELINDEX is the 0-based level index (matches
%   lightsheetZarrLevel.level).
%
%   TARGETVOXELSIZE may be a scalar (applied to every spatial axis) or a
%   vector aligned with the level's `voxel_size`.
%
%   See also: ndi.fun.doc.lightsheet.levelTable

    arguments
        levels
        targetVoxelSize (1,:) double
    end

    if istable(levels)
        vs = levels.voxel_size;
        li = levels.level;
        n = height(levels);
    else
        n = numel(levels);
        vs = cell(n, 1);
        li = zeros(n, 1);
        for k = 1:n
            vs{k} = reshape(double(levels(k).voxel_size), 1, []);
            li(k) = levels(k).level;
        end
    end
    if n == 0
        error('NDI:lightsheet:chooseLevel:emptyLevels', ...
            'levels is empty.');
    end

    bestK = 1;
    for k = 1:n
        v = vs{k};
        if isscalar(targetVoxelSize)
            ok = all(v <= targetVoxelSize);
        else
            m = min(numel(v), numel(targetVoxelSize));
            ok = all(v(1:m) <= targetVoxelSize(1:m));
        end
        if ok
            bestK = k;
        end
    end

    levelIndex = li(bestK);
    if istable(levels)
        levelRow = levels(bestK, :);
    else
        levelRow = levels(bestK);
    end
end
