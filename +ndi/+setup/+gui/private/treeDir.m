function treeListing = treeDir(rootPath, options)
%treeDir Create a tree listing of a directory tree
%
%   Syntax:
%       treeListing = treeDir(rootPath, options)
%   
%
%   Input arguments:
%
%   Output arguments:
%       treeListing - A nested struct where each substruct represents a 
%           folder and the bottommost is a fileList struct. 

% Inspired by recursiveDir, but this function returns a custom struct meant
% for being plotted in a uitree component
%
% Used by DaqSystemConfigurator

    arguments
        rootPath (1,:) string
        options.TotalDepth (1,1) double = inf
        options.IgnoreList (1,:) string = string.empty
        options.Expression (1,1) string = ""
        options.Type (1,1) string {validatestring(options.Type, {'file', 'folder', 'all'})} = "all"
        options.FileType (1,1) string = ""
    end
    
    treeListing = struct();
    treeListing.FolderPath = rootPath;
    [~, treeListing.FolderName] = fileparts(rootPath);
    treeListing.Subfolders = struct.empty;
    treeListing.Files = empty();

    %combinedListing = empty();

    if numel(rootPath) > 1
        newListing = cell(1,numel(rootPath));
        for i = 1:numel(rootPath)
            nvpairs = namedargs2cell(options);
            newListing{i} = treeDir(rootPath(i), nvpairs{:});
        end
        treeListing = cat(2, newListing{:});
    else
        % Find folders in root path
        newListing = dir(fullfile(rootPath));
        
        % 1. Remove "shadow" files / hidden files
        newListing(strncmp({newListing.name}, '.', 1)) = [];
        
        % 2. Filter listing by exclusion criteria
        keep = true(1, numel(newListing));

        % Remove folders that contain a word from the ignore list.
        if ~isempty(options.IgnoreList)
            ignore = contains({newListing.name}, options.IgnoreList);
            keep = keep & ~ignore;
        end

        filteredListing = newListing(keep);
        keep = true(1, numel(filteredListing)); 

        % 3. Keep only list items that matches expression
        if options.Expression ~= ""
            isValidName = @(fname) ~isempty(regexp(fname, options.Expression, 'once'));
            isMatch = cellfun(@(name) isValidName(name), {newListing.name} );
            keep = keep & isMatch;
        end


        % 4. Select only files or folders if this is an option
        if options.Type == "file"
            keep = keep & ~[filteredListing.isdir];
        elseif options.Type == "folder"
            keep = keep & [filteredListing.isdir];
        end

        % 5. Filter by filetype if this is an option
        if options.FileType ~= "" && ~strncmp(options.FileType, '.', 1)
            options.FileType = sprintf('.%s', options.FileType);
        end
        
        if options.Type == "file" && options.FileType ~= ""
            [~, ~, ext] = fileparts({filteredListing.name});
            isValidFiletype = strcmp(ext, options.FileType);
            keep = keep & isValidFiletype;
        end
        
        keepListing = filteredListing(keep);

        isFile = ~[keepListing.isdir];
        treeListing.Files = keepListing(isFile);

        if options.TotalDepth > 0 && sum([filteredListing.isdir]) > 0
            
            % Continue search through subfolders that passed the filter
            newRootPath = arrayfun(@(l) string(fullfile(l.folder, l.name)), filteredListing, 'uni', 1);
            newRootPath(~[newListing.isdir])=[];
            
            options.TotalDepth = options.TotalDepth - 1;

            nvpairs = namedargs2cell(options);
            subListing = treeDir(newRootPath, nvpairs{:});
            if ~isempty(subListing)
                treeListing.Subfolders = subListing;
            end
        end
    end
end

function S = empty()
%empty Return an empty struct with the same fields the struct returned by dir.
    S = struct(...
    'name', {}, ...
    'folder', {}, ...
    'date', {}, ...
    'bytes', {}, ...
    'isdir', {}, ...
    'datenum', {});
    S = reshape(S, 0, 1);
end
