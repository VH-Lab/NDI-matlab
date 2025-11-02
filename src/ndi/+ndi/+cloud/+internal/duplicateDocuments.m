function [duplicateDocs, originalDocs] = duplicateDocuments(cloudDatasetId, options)
% DUPLICATEDOCUMENTS - Find and optionally remove duplicate documents in a cloud dataset
%
% [DUPLICATEDOCS, ORIGINALDOCS] = ndi.cloud.internal.duplicateDocuments(CLOUDDATASETID, ...)
%
% This function identifies duplicate documents within a specified NDI cloud dataset.
% Duplicates are defined as documents that share the same 'ndi.document.id' but may have
% different cloud-specific '_id' values. This situation can arise, for example,
% when a dataset is copied or merged on the cloud.
%
% The function determines which document to keep as the 'original' and which to
% mark as a 'duplicate' based on the alphabetical order of their 'cloud_dataset_id'.
% The document with the alphabetically earliest 'cloud_dataset_id' is considered
% the original, and all others with the same 'ndi.document.id' are duplicates.
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
end

duplicateDocs = struct('id', {});
originalDocs = struct('id', {});

disp(['Searching for all documents...']);
[~, allDocs] = ndi.cloud.api.documents.listDatasetDocumentsAll(cloudDatasetId);
disp(['Done.']);

if isempty(allDocs)
    return;
end

% Use a map to track documents by their NDI ID
docMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

% Identify originals and duplicates
for i = 1:numel(allDocs)
    currentDoc = allDocs(i);
    ndiId = currentDoc.document_properties.ndi_document.id;

    if ~isKey(docMap, ndiId)
        % First time seeing this NDI ID, so it's the current original
        docMap(ndiId) = currentDoc;
    else
        % We have a potential duplicate, decide which is the original
        existingDoc = docMap(ndiId);

        % The one with the alphabetically earlier cloud_dataset_id is the original
        if strcmp(currentDoc.document_properties.cloud_dataset_id, existingDoc.document_properties.cloud_dataset_id) < 0
            % The new one is the original, the old one is a duplicate
            duplicateDocs(end+1) = existingDoc;
            docMap(ndiId) = currentDoc;
        else
            % The old one is the original, the new one is a duplicate
            duplicateDocs(end+1) = currentDoc;
        end
    end
end

% The originals are the final values left in the map
originalDocs = values(docMap)';

% Delete duplicates if requested
if options.deleteDuplicates && ~isempty(duplicateDocs)
    disp(['Found ' int2str(numel(duplicateDocs)) ' duplicates to delete.']);

    docIdsToDelete = {duplicateDocs.id};

    numBatches = ceil(numel(docIdsToDelete) / options.maximumDeleteBatchSize);

    for i = 1:numBatches
        startIndex = (i-1) * options.maximumDeleteBatchSize + 1;
        endIndex = min(i * options.maximumDeleteBatchSize, numel(docIdsToDelete));

        batchIds = docIdsToDelete(startIndex:endIndex);

        disp(['Deleting batch ' int2str(i) ' of ' int2str(numBatches) '...']);
        ndi.cloud.api.documents.bulkDeleteDocuments(cloudDatasetId, batchIds);
        disp(['Batch ' int2str(i) ' deleted.']);
    end

    disp('All duplicate documents deleted.');
else
    if isempty(duplicateDocs)
        disp('No duplicate documents found.');
    else
        disp(['Found ' int2str(numel(duplicateDocs)) ' duplicates, but deletion was not requested.']);
    end
end

end
