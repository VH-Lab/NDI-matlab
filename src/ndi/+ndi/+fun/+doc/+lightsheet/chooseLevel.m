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
%   A LEVEL THAT STORES NO BYTES IS SKIPPED (Decided by Jess Haley,
%   2026-10-26 [chooseLevel skips empty levels], did-schema
%   V_eta_go_forward_class_audit.md): when LEVELS carries `n_chunks_stored`
%   (levelTable's column; a v1 lightsheetZarrLevel's field), a level with
%   n_chunks_stored == 0 -- a level written with materializeChunks off, and
%   the file-less sampled_body the migration makes of one ([compression block
%   and empty levels]) -- is never chosen while a level that stores bytes is
%   there. Before it, two levels that tie on voxel size (a max and a mean
%   level 1, one of them empty) went to whichever came last. A level with no
%   `n_chunks_stored` counts as storing bytes. When EVERY level stores none,
%   the choice is made over all of them, as before, so a caller still gets a
%   level (and its metadata) back.
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
        stored = true(n, 1);
        if any(strcmp(levels.Properties.VariableNames, 'n_chunks_stored'))
            stored = storesBytes(levels.n_chunks_stored);
        end
    else
        n = numel(levels);
        vs = cell(n, 1);
        li = zeros(n, 1);
        stored = true(n, 1);
        for k = 1:n
            vs{k} = reshape(double(levels(k).voxel_size), 1, []);
            li(k) = levels(k).level;
            if isfield(levels, 'n_chunks_stored')
                stored(k) = levelStoresBytes(levels(k).n_chunks_stored);
            end
        end
    end
    if n == 0
        error('NDI:lightsheet:chooseLevel:emptyLevels', ...
            'levels is empty.');
    end

    % [chooseLevel skips empty levels]: only levels that store bytes are
    % candidates, unless none does
    candidates = find(stored);
    if isempty(candidates)
        candidates = (1:n).';
    end
    bestK = candidates(1);
    for k = reshape(candidates, 1, [])
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

function tf = storesBytes(col)
    % One logical per level, from the `n_chunks_stored` table column.
    if iscell(col)
        tf = cellfun(@levelStoresBytes, col);
    else
        tf = arrayfun(@levelStoresBytes, col);
    end
    tf = reshape(tf, [], 1);
end

function tf = levelStoresBytes(n)
    % false only for a stated 0. Empty, NaN or anything not numeric is
    % "not stated" and counts as storing bytes.
    tf = true;
    if isempty(n) || ~(isnumeric(n) || islogical(n))
        return;
    end
    tf = ~all(double(n(:)) == 0);
end
