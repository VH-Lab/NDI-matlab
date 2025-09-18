function [b,msg] = dataset_documents(dataset, mode, jsonpath, filepath, options)
    %DATASET_DOCUMENTS download dataset documents from NDI Cloud
    %
    % [B, MSG] = ndi.cloud.download.dataset_documents(DATASET, JSONPATH, ...])
    %
    % Inputs:
    %   DATASET     - The dataset structure returned from ndi.cloud.api.datasets.get_dataset % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.get_dataset with ndi.cloud.api.datasets.getDataset
    %   MODE        - 'local' to download all files locally,
    %                 'hybrid' to leave binary files in cloud    
    %   JSONPATH    - location to save documents
    %   FILEPATH    - location to save files
    % Optional inputs (as name/value pairs):
    %   verbose     - Should output be verbose? (default: true)
    %
    % Outputs:
    %   B - did the download work? 0 for no, 1 for yes
    %   MSG - An error message if the download failed; otherwise ''

    arguments
        dataset struct
        mode (1,:) char {mustBeMember(mode,{'local','hybrid'})}        
        jsonpath (1,:) char {mustBeFolder}
        filepath (1,:) char {mustBeFolder}
        options.verbose logical = true
    end

    msg = '';
    b = 1;

    verbose = options.verbose;

    if verbose, disp(['Will download ' int2str(numel(dataset.documents)) ' documents...']); end
    d = dataset.documents;

    % take an inventory of documents we already have

    here_already = [];

    for i=1:numel(d)
        document_id = d{i};
        json_file_path = fullfile(jsonpath,[document_id '.json']);
        if isfile(json_file_path)
            here_already(end+1)=i;
        end
    end

    for i = 1:numel(d)
        if verbose, disp(['Downloading document ' int2str(i) ' of ' int2str(numel(d))  ' (' num2str(100*(i)/numel(d))  '%)' '...']); end
        document_id = d{i};
        json_file_path = fullfile(jsonpath,[document_id '.json']);
        if isfile(json_file_path)
            if verbose, disp(['Document ' int2str(i) ' already exists. Skipping...']); end
            continue;
        end

        % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.get_document with ndi.cloud.api.documents.getDocument
        [response, docStruct] = ndi.cloud.api.documents.get_document(dataset.x_id, document_id);
        
        if verbose, disp(['Saving document ' int2str(i) '...']); end

        docStruct = rmfield(docStruct, 'id');
        docStruct = ndi.cloud.download.internal.set_file_info(docStruct,mode,filepath);

        document_obj = ndi.document(docStruct);
        % save the document in .json file
        did.file.str2text(json_file_path,did.datastructures.jsonencodenan(document_obj));
    end
end
