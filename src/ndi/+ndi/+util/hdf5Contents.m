function [T, verdict] = hdf5Contents(filename, options)
%HDF5CONTENTS Table of contents for an HDF5 file, including .gef and .h5ad.
%
%   NDI.UTIL.HDF5CONTENTS(FILENAME) prints what is in an HDF5 container:
%   every group and dataset with its size and class, the attributes that
%   carry the metadata, and a verdict on what KIND of file it is.
%
%   T = NDI.UTIL.HDF5CONTENTS(FILENAME) returns the listing as a table
%   instead of printing it. [T, VERDICT] also returns the verdict as a
%   string array, so a caller -- or a test -- can act on what kind of
%   file it is rather than reading it off the screen.
%
%   WHY THIS EXISTS. A Stereo-seq run leaves several files with the same
%   stem and different middles -- Y00709C1E2.tissue.gef,
%   Y00709C1E2.adjusted.cellbin.gef -- and the extension does not say
%   which is which. All of them are HDF5; .gef is a layout inside HDF5,
%   not a format beside it, so "is this really an h5?" is always yes and
%   never the question. The question is which GROUPS it holds, because
%   that is what decides whether ndi.fun.doc.gene.fromGEF can read it:
%
%     /geneExp/binN or /wholeExp/binN   square-bin expression. This is
%                                       what makes a pyramid.
%     /cellBin                          per-cell expression from SAW's
%                                       CellBin step. NOT a square-bin
%                                       GEF, and not what fromGEF wants.
%     /obs and /X                       AnnData (.h5ad). The cellbin
%                                       .h5ad that fromCellBin reads.
%
%   Optional Name-Value Arguments:
%   maxDepth (4)         - how deep to descend. Deep enough to reach a
%                          bin group's datasets, shallow enough that an
%                          .h5ad's thousands of /obs columns do not fill
%                          the screen.
%   attributes (true)    - list attributes as well as datasets. They are
%                          where SAW puts minX/maxX, resolution and the
%                          chip serial, so they are on by default.
%   maxChildren (40)     - stop listing a group's members after this
%                          many, and say how many were left. An /obs
%                          group with 2,000 columns is otherwise the
%                          whole output.
%
%   Outputs:
%   T       - table with path, kind ("group"/"dataset"/"attribute"/"note"),
%             size and class. With no output requested the listing is
%             printed instead.
%   VERDICT - string array naming what kind of file this is, and what can
%             read it.
%
%   Example:
%       ndi.util.hdf5Contents('Y00709C1E2.tissue.gef')
%       ndi.util.hdf5Contents('Y00709C1E2.adjusted.cellbin.gef')
%
%   See also: h5info, h5disp, ndr.format.stereoseq.readGEF,
%             ndr.format.stereoseq.readCellBin, ndi.util.hexDump

arguments
    filename (1,:) char {mustBeFile}
    options.maxDepth (1,1) {mustBeInteger, mustBePositive} = 4
    options.attributes (1,1) logical = true
    options.maxChildren (1,1) {mustBeInteger, mustBePositive} = 40
end

try
    info = h5info(filename);
catch ME
    error('NDI:util:hdf5Contents:notHDF5', ...
        ['%s cannot be read as HDF5 (%s).\n\nA .gef IS an HDF5 file, so ' ...
         'this failing means the file is truncated, is not HDF5 at all, ' ...
         'or is a format MATLAB''s h5info does not recognise.'], ...
        filename, ME.message);
end

rows = localWalk(info, '', 1, options);
T = struct2table(rows, 'AsArray', true);
verdict = localVerdict(T);

if nargout == 0
    localPrint(filename, T, verdict);
    clear T verdict;
end

end % hdf5Contents

% ------------------------------------------------------------------------

function rows = localWalk(node, parentPath, depth, options)
% One row per group, dataset and attribute, breadth first within a level.
rows = struct('path', {}, 'kind', {}, 'size', {}, 'class', {});
if depth > options.maxDepth
    return;
end

here = parentPath;
if ~isempty(node.Name) && ~strcmp(node.Name, '/')
    here = [parentPath '/' node.Name];
elseif isempty(parentPath)
    here = '';
end

if options.attributes && isfield(node, 'Attributes')
    for i = 1:numel(node.Attributes)
        a = node.Attributes(i);
        rows(end+1) = struct('path', string([here '/@' a.Name]), ...
            'kind', "attribute", 'size', localValueText(a.Value), ...
            'class', string(class(a.Value))); %#ok<AGROW>
    end
end

if isfield(node, 'Datasets')
    n = numel(node.Datasets);
    for i = 1:min(n, options.maxChildren)
        d = node.Datasets(i);
        rows(end+1) = struct('path', string([here '/' d.Name]), ...
            'kind', "dataset", 'size', localSizeText(d.Dataspace), ...
            'class', string(localTypeText(d.Datatype))); %#ok<AGROW>
    end
    if n > options.maxChildren
        rows(end+1) = struct('path', string(sprintf('%s/... %d more dataset(s)', ...
            here, n - options.maxChildren)), 'kind', "note", ...
            'size', "", 'class', "");
    end
end

if isfield(node, 'Groups')
    n = numel(node.Groups);
    for i = 1:min(n, options.maxChildren)
        g = node.Groups(i);
        % h5info gives groups their FULL path already; take the leaf so
        % the row reads as a path rather than repeating its ancestors.
        parts = strsplit(g.Name, '/');
        leaf = parts{end};
        gpath = [here '/' leaf];
        rows(end+1) = struct('path', string(gpath), 'kind', "group", ...
            'size', "", 'class', ""); %#ok<AGROW>
        sub = g;
        sub.Name = leaf;
        rows = [rows, localWalk(sub, here, depth + 1, options)]; %#ok<AGROW>
    end
    if n > options.maxChildren
        rows(end+1) = struct('path', string(sprintf('%s/... %d more group(s)', ...
            here, n - options.maxChildren)), 'kind', "note", ...
            'size', "", 'class', "");
    end
end

end

function s = localSizeText(space)
if isempty(space) || ~isfield(space, 'Size') || isempty(space.Size)
    s = "";
    return;
end
s = string(strjoin(arrayfun(@(v) sprintf('%d', v), space.Size, ...
    'UniformOutput', false), ' x '));
end

function s = localTypeText(dt)
if isstruct(dt) && isfield(dt, 'Class')
    s = dt.Class;
    if strcmp(s, 'H5T_COMPOUND') && isfield(dt, 'Type') && ...
            isstruct(dt.Type) && isfield(dt.Type, 'Member')
        s = ['compound(' strjoin({dt.Type.Member.Name}, ',') ')'];
    end
else
    s = '?';
end
end

function s = localValueText(v)
% Attributes are the metadata, so their VALUES are the point -- a size
% would say nothing. Long ones are truncated rather than wrapped.
try
    if ischar(v) || isstring(v)
        s = string(strjoin(cellstr(v), ', '));
    elseif isnumeric(v) && numel(v) <= 6
        s = string(strjoin(arrayfun(@(x) sprintf('%g', x), v(:)', ...
            'UniformOutput', false), ', '));
    else
        s = string(sprintf('<%s>', strjoin(string(size(v)), 'x')));
    end
catch
    s = "<unreadable>";
end
if strlength(s) > 60
    s = extractBefore(s, 58) + "...";
end
end

function v = localVerdict(T)
% What KIND of file this is, from the groups it holds. This is the
% question the listing is usually being read to answer.
p = T.path;
hasBin = any(startsWith(p, "/geneExp/bin") | startsWith(p, "/wholeExp/bin"));
hasCellBin = any(startsWith(p, "/cellBin"));
hasObs = any(startsWith(p, "/obs"));
hasX = any(p == "/X" | startsWith(p, "/X/"));

v = strings(0,1);
if hasBin
    v(end+1) = "square-bin GEF: /geneExp or /wholeExp bins are present, " + ...
        "so ndi.fun.doc.gene.fromGEF can build a pyramid from this.";
end
if hasCellBin
    v(end+1) = "CellBin GEF: /cellBin holds per-cell expression. This is " + ...
        "NOT a square-bin GEF. fromCellBin reads the cellbin .h5ad, not " + ...
        "this, so there is no ingest path for it today.";
end
if hasObs && hasX
    v(end+1) = "AnnData (.h5ad): /obs and /X are present, which is what " + ...
        "ndi.fun.doc.gene.fromCellBin reads.";
end
if isempty(v)
    v(end+1) = "no /geneExp, /wholeExp, /cellBin or /obs group at this " + ...
        "depth. Raise maxDepth, or this is an HDF5 file of another kind.";
end
end

function localPrint(filename, T, verdict)
d = dir(filename);
fprintf('\n%s  (%.2f GB)\n', filename, d.bytes/1e9);
fprintf('%s\n', repmat('-', 1, 72));
for i = 1:height(T)
    switch T.kind(i)
        case "group"
            fprintf('  %-46s %s\n', T.path(i), '[group]');
        case "attribute"
            fprintf('  %-46s = %s\n', T.path(i), T.size(i));
        case "note"
            fprintf('  %s\n', T.path(i));
        otherwise
            fprintf('  %-46s %-14s %s\n', T.path(i), T.size(i), T.class(i));
    end
end
fprintf('%s\n', repmat('-', 1, 72));
for i = 1:numel(verdict)
    fprintf('  %s\n', verdict(i));
end
fprintf('\n');
end
