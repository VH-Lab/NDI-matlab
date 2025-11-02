function [duplicateDocs, originalDocs] = duplicateDocuments(cloudDatasetId, options)
% DUPLICATEDOCUMENTS - Find and optionally remove duplicate documents in a cloud dataset
%
% [DUPLICATEDOCS, ORIGINALDOCS] = ndi.cloud.internal.duplicateDocuments(CLOUDDATASETID, ...)
%
% This function identifies duplicate documents within a specified NDI cloud dataset.
% Duplicates are defined as documents that share the same 'ndi.document.id' (or 'name'
% as a fallback) but may have different cloud-specific '_id' values.
%
% The function determines which document to keep as the 'original' and which to
% mark as a 'duplicate' based on the alphabetical order of their unique cloud document
% ID ('id'). The one with the alphabetically earliest 'id' is kept.
%
% By default, this function will delete the identified duplicate documents from the
% cloud dataset. This behavior can be controlled using a name-value pair.
%
% This function can take additional name-value pair arguments:
% |--------------------------|-----------------------------------------------|
% | 'deleteDuplicates'       | A boolean value (true/false) indicating       |
% |                          | whether to delete the identified duplicates.  |
% |                          | (Default: true)                               |
% | 'maximumDeleteBatchSize' | The maximum number of documents to delete in  |
% |                          | a single bulk operation.                      |
% |                          | (Default: 100)                                |
% | 'verbose'                | A boolean value (true/false) indicating       |
% |                          | whether to display status messages.           |
% |                          | (Default: false)                              |
%
% Outputs:
%   DUPLICATEDOCS - A struct array of the documents that were identified as
%                   duplicates. These are the documents that were deleted if
%                   'deleteDuplicates' is true.
%   ORIGINALDOCS  - A struct array of the documents that were identified as
%                   the originals.
%
% See also: ndi.cloud.api.documents.listDatasetDocumentsAll,
%           ndi.cloud.api.documents.bulkDeleteDocuments

arguments
    cloudDatasetId (1,:) char {mustBeText}
    options.deleteDuplicates (1,1) logical = true
    options.maximumDeleteBatchSize (1,1) {mustBeInteger, mustBePositive} = 100
    options.verbose (1,1) logical = false
end

duplicateDocs = struct([]);
originalDocs = struct([]);

if options.verbose
    disp(['Searching for all documents...']);
end
[~, allDocsStruct] = ndi.cloud.api.documents.listDatasetDocumentsAll(cloudDatasetId);
if options.verbose
    disp(['Done.']);
end

if isempty(allDocsStruct)
    return;
end

% --- Struct Normalization ---
% Get all unique field names from all document summaries
allFields = {};
for i = 1:numel(allDocsStruct)
    allFields = union(allFields, fieldnames(allDocsStruct(i)));
end

% Create a template struct with all fields initialized to empty
templateStruct = struct();
for i = 1:numel(allFields)
    templateStruct.(allFields{i}) = [];
end

% Create a normalized array of structs
allDocs = repmat(templateStruct, numel(allDocsStruct), 1);
for i = 1:numel(allDocsStruct)
    currentDoc = allDocsStruct(i);
    fields = fieldnames(currentDoc);
    for j = 1:numel(fields)
        allDocs(i).(fields{j}) = currentDoc.(fields{j});
    end
end
% --- End Normalization ---

% Now that we have a homogeneous struct array, initialize the outputs
duplicateDocs = allDocs([]);

docMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

% Identify originals and duplicates
for i = 1:numel(allDocs)
    currentDoc = allDocs(i);

    if isfield(currentDoc, 'ndiId') && ~isempty(currentDoc.ndiId)
        doc_group_key = currentDoc.ndiId;
    else
        doc_group_key = currentDoc.name;
    end

    if ~isKey(docMap, doc_group_key)
        docMap(doc_group_key) = currentDoc;
    else
        existingDoc = docMap(doc_group_key);
        if strcmp(currentDoc.id, existingDoc.id) < 0
            duplicateDocs(end+1) = existingDoc;
            docMap(doc_group_key) = currentDoc;
        else
            duplicateDocs(end+1) = currentDoc;
        end
    end
end

originalDocsCell = values(docMap);
if ~isempty(originalDocsCell)
    originalDocs = [originalDocsCell{:}]';
else
    originalDocs = allDocs([]);
end

if options.deleteDuplicates && ~isempty(duplicateDocs)
    if options.verbose
        disp(['Found ' int2str(numel(duplicateDocs)) ' duplicates to delete.']);
    end

    docIdsToDelete = {duplicateDocs.id};

    numBatches = ceil(numel(docIdsToDelete) / options.maximumDeleteBatchSize);

    for i = 1:numBatches
        startIndex = (i-1) * options.maximumDeleteBatchSize + 1;
        endIndex = min(i * options.maximumDeleteBatchSize, numel(docIdsToDelete));

        batchIds = docIdsToDelete(startIndex:endIndex);

        if options.verbose
            disp(['Deleting batch ' int2str(i) ' of ' int2str(numBatches) '...']);
        end
        ndi.cloud.api.documents.bulkDeleteDocuments(cloudDatasetId, batchIds);
        if options.verbose
            disp(['Batch ' int2str(i) ' deleted.']);
        end
    end

    if options.verbose
        disp('All duplicate documents deleted.');
    end
else
    if isempty(duplicateDocs)
        if options.verbose
            disp('No duplicate documents found.');
        end
    else
        if options.verbose
            disp(['Found ' int2str(numel(duplicateDocs)) ' duplicates, but deletion was not requested.']);
        end
    end
end

end
