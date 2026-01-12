function datasetSessionId = datasetSessionIdFromDocs(docs)
% DATASETSESSIONIDFROMDOCS - Extract the unique session ID from a list of documents
%
% DATASETSESSIONID = DATASETSESSIONIDFROMDOCS(DOCS)
%
% Inputs:
%   DOCS - a cell array of NDI_DOCUMENT objects
%
% Outputs:
%   DATASETSESSIONID - the session ID (character array)
%
% This function searches through the input documents for documents with 'document_class'
% of 'session' and 'dataset_session_info'. It collects 'session_id's from 'session'
% documents and removes those present in the 'dataset_session_info' document(s).
% It returns the remaining unique session ID.
%
% See also: NDI_DOCUMENT

    arguments
        docs cell
    end

    dataset_session_info_doc_inds = [];

    allSessions = {};
    confirmedSessionIds = {};
    datasetSessionId = '';

    for i = 1:numel(docs)
        docClass = docs{i}.document_properties.document_class;
        className = '';
        if ischar(docClass) || isstring(docClass)
            className = char(docClass);
        elseif isstruct(docClass) && isfield(docClass, 'class_name')
            className = docClass.class_name;
        end

        if strcmp(className, 'session')
            allSessions{end+1} = docs{i}.document_properties.base.session_id;
        elseif strcmp(className, 'dataset_session_info')
            dataset_session_info_doc_inds(end+1) = i;
        elseif strcmp(className, 'session_in_a_dataset')
            confirmedSessionIds{end+1} = docs{i}.document_properties.session_in_a_dataset.session_id;
        end
    end

    if numel(dataset_session_info_doc_inds) > 1
        error('ndi:cloud:sync:internal:datasetSessionIdFromDocs:tooManyDatasetSessionInfo', ...
            'More than 1 dataset_session_info document found.');
    end

    if ~isempty(dataset_session_info_doc_inds)
        ds_info = docs{dataset_session_info_doc_inds(1)}.document_properties.dataset_session_info.dataset_session_info;
        % ds_info is a struct array
        for k = 1:numel(ds_info)
            confirmedSessionIds{end+1} = ds_info(k).session_id;
        end
    end

    potentialIds = setdiff(allSessions, confirmedSessionIds);

    if numel(potentialIds) ~= 1
         error('ndi:cloud:sync:internal:datasetSessionIdFromDocs:invalidSessionCount', ...
            'Expected exactly 1 session ID after filtering, but found %d.', numel(potentialIds));
    end

    datasetSessionId = potentialIds{1};
end
