function files = discover(root, options)
%DISCOVER Stage 0 of a V2 import: list the source files under ROOT.
%
%   FILES = ndi.setup.V2.discover(ROOT) walks ROOT and returns a table with
%   one row per file: path (relative to ROOT), folder, name, ext, bytes and
%   modified. Nothing is read or assumed about what the files mean -- that is
%   what the later stages ask about.
%
%   An import's OWN earlier output is skipped by default, because profiling
%   it would describe the last import instead of the data: NDI databases
%   (`.ndi`, and the `.ndi_` copies doImport makes), dataset folders (any
%   folder holding a `.ndi` of its own is still skipped by that rule),
%   archives, and OS clutter. Pass 'Skip' to change the list; every skipped
%   path is COUNTED and reported, never silently dropped.
%
%   Options:
%     'Skip'         cellstr of folder names or extensions/names to skip
%                    (default {'.ndi', '.ndi_', '.DS_Store', '__MACOSX', '.zip'})
%     'SkipFolders'  cellstr of additional folder paths, relative to ROOT
%     'Verbose'      default true: print the denominator
%
%   The denominator is printed first (Operating Rule 5): folders walked,
%   files seen, files kept, and files skipped by which rule.
%
%   See also ndi.setup.V2.profileTable.

arguments
    root (1,:) char {mustBeFolder}
    options.Skip cell = {'.ndi', '.ndi_', '.DS_Store', '__MACOSX', '.zip'}
    options.SkipFolders cell = {}
    options.Verbose (1,1) logical = true
end

listing = dir(fullfile(root, '**', '*'));
isDir = [listing.isdir];
names = {listing.name};
dirs = listing(isDir & ~ismember(names, {'.', '..'}));
listing = listing(~isDir);

path = cell(numel(listing), 1);
keep = true(numel(listing), 1);
skippedBy = containers.Map();
for k = 1:numel(listing)
    full = fullfile(listing(k).folder, listing(k).name);
    rel = full(numel(root) + 2:end);
    path{k} = rel;
    parts = strsplit(rel, filesep);
    [~, ~, ext] = fileparts(listing(k).name);
    rule = '';
    hit = intersect(parts(1:end-1), options.Skip);
    if ~isempty(hit)
        rule = ['folder ' hit{1}];
    elseif any(strcmp(ext, options.Skip))
        rule = ['ext ' ext];
    elseif any(strcmp(listing(k).name, options.Skip))
        rule = ['name ' listing(k).name];
    else
        for s = 1:numel(options.SkipFolders)
            if startsWith(rel, [options.SkipFolders{s} filesep])
                rule = ['folder ' options.SkipFolders{s}];
                break;
            end
        end
    end
    if ~isempty(rule)
        keep(k) = false;
        if isKey(skippedBy, rule), skippedBy(rule) = skippedBy(rule) + 1;
        else, skippedBy(rule) = 1; end
    end
end

listing = listing(keep);
path = path(keep);
[folder, name, ext] = cellfun(@fileparts, path, 'UniformOutput', false);
files = table(path, folder, name, ext, [listing.bytes]', ...
    datetime([listing.datenum]', 'ConvertFrom', 'datenum'), ...
    'VariableNames', {'path', 'folder', 'name', 'ext', 'bytes', 'modified'});
files = sortrows(files, 'path');

if options.Verbose
    fprintf('DENOMINATOR: %d folder(s) walked under %s; %d file(s) seen, %d kept, %d skipped\n', ...
        numel(dirs), root, numel(keep), sum(keep), sum(~keep));
    rules = keys(skippedBy);
    for r = 1:numel(rules)
        fprintf('  skipped %6d  by %s\n', skippedBy(rules{r}), rules{r});
    end
end
end
