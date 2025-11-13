function docTypes = allTypes()
% ALLTYPES - Return all known NDI document class types
%
% DOCTYPES = ndi.fun.doc.allTypes()
%
% Returns a cell array of all known NDI document class types.
%
% This function searches the NDI document paths for all .json files
% that define NDI documents and returns the names of these documents.
%
% The paths that are searched are given in
% ndi.common.PathConstants.DocumentFolder and
% ndi.common.PathConstants.CalcDoc
%
% See also: ndi.document
%

% 1. Find all .json files in the primary and calculated document folders
json_docs = vlt.file.findfilegroups(ndi.common.PathConstants.DocumentFolder, {'.*\.json\>'});

calcDocPaths = ndi.common.PathConstants.CalcDoc;
if ~iscell(calcDocPaths)
    calcDocPaths = {calcDocPaths};
end

for i = 1:numel(calcDocPaths)
    if isfolder(calcDocPaths{i})
        more_json_docs = vlt.file.findfilegroups(calcDocPaths{i}, {'.*\.json\>'});
        json_docs = cat(1, json_docs, more_json_docs);
    end
end

% 2. Process the list of full file paths into a clean list of type names
docTypes = {};
for i = 1:numel(json_docs)
    % Each entry in json_docs is a cell array, get the first file path
    [~, filename, ~] = fileparts(json_docs{i}{1});

    % Ignore hidden files (like '.DS_Store') or swap files
    if filename(1) ~= '.'
        docTypes{end+1} = filename;
    end

end

% 3. Ensure the list is unique and sort it for consistent test order
docTypes = unique(docTypes)'; % make it a column vector of char arrays

end
