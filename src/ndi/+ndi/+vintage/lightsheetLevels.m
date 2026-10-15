function [recs, vintages] = lightsheetLevels(levelDocs, pyramidDoc)
%LIGHTSHEETLEVELS Every level of one pyramid, by v1 field names, with level indices.
%
%   [RECS, VINTAGES] = ndi.vintage.lightsheetLevels(LEVELDOCS, PYRAMIDDOC)
%
%   LEVELDOCS is a cell of level documents of ONE pyramid (as
%   ndi.vintage.lightsheetLevelDocs returns them). RECS is a 1-by-N cell of
%   ndi.vintage.lightsheetLevel structs in the same order, VINTAGES a cellstr.
%
%   A v1 level carries its own `level` and is returned as it is.
%
%   A V_eta level does not carry its index: DID-matlab
%   +migrators_j/lightsheet_zarr_level.m drops `level` as derivable. It is
%   derived here from the set, by the two facts the migrator does keep:
%     * level 0 is the one body NOT `redundant` (the measurement, #73 L1);
%     * every other level is `redundant`, and within one reduction its index
%       is its rank by resolution, finest first: 1, 2, ... in order of
%       decreasing voxel count (prod(shape)).
%   KNOWN LIMIT, carried rather than guessed around: a v1 level that held no
%   bytes folded to NOTHING in the migration (#73 L3(c)), so if an
%   intermediate level of a ladder was never materialized, the levels above
%   it rank one lower than their v1 index. The order and the shapes are
%   right; only the integer can differ.
%
%   See also: ndi.vintage.lightsheetLevel, ndi.fun.doc.lightsheet.levelTable.

n = numel(levelDocs);
recs = cell(1, n);
vintages = cell(1, n);
for k = 1:n
    [recs{k}, vintages{k}] = ndi.vintage.lightsheetLevel(levelDocs{k}, pyramidDoc);
end

eta = find(strcmp(vintages, 'V_eta'));
if isempty(eta)
    return;
end
redundant = cellfun(@(r) r.redundant, recs(eta));
for k = reshape(eta(~redundant), 1, [])
    recs{k}.level = 0;
end
red = eta(redundant);
if isempty(red)
    return;
end
reductions = cellfun(@(r) r.reduction_function, recs(red), 'UniformOutput', false);
groups = unique(reductions);
for gi = 1:numel(groups)
    members = red(strcmp(reductions, groups{gi}));
    voxels = cellfun(@(r) prod(double(r.shape)), recs(members));
    ladder = unique(voxels);              % ascending
    ladder = ladder(end:-1:1);            % finest (most voxels) first
    for k = reshape(members, 1, [])
        recs{k}.level = find(ladder == prod(double(recs{k}.shape)), 1);
    end
end
end
