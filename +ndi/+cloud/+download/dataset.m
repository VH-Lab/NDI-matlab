function [b,msg, D] = dataset(dataset_id, mode, output_path, options)
    %DATASET download a dataset from NDI Cloud
    %
    % [B, MSG] = ndi.cloud.download.dataset(DATASET_ID, MODE, [OUTPUT_PATH])
    %
    % Inputs:
    %   DATASET_ID  - The dataset ID to download
    %   MODE        - 'local' to download all files locally,
    %                 'hybrid' to leave binary files in cloud
    %   OUTPUT_PATH - The path to download the dataset to. If not
    %                 provided, the user will be prompted.
    %
    % Outputs:
    %   B - did the download work? 0 for no, 1 for yes
    %   MSG - An error message if the download failed; otherwise ''

    arguments
        dataset_id
        mode (1,:) char {mustBeMember(mode,{'local','hybrid'})}
        output_path = ''
        options.verbose logical = true
    end

    msg = '';
    b = 1;

    if isempty(output_path),
        output_path = uigetdir(pwd,'Select a directory where the dataset should be placed...');

        if ~ischar(output_path),
            b = 0;
            msg = 'Cancelling per user request.';
            D = [];
        end;
    end;

    output_path = char(output_path);
    %%Construct a folder to hold our ndi.dataset.dir object
    if ~isfolder(output_path)
        mkdir(output_path);
    end

    filepath = fullfile(output_path,'download','files');
    jsonpath = fullfile(output_path,'download','json');


    verbose = options.verbose;

    if verbose, disp(['Retrieving dataset...']); end

    [status,dataset, response] = ndi.cloud.api.datasets.get_datasetId(dataset_id);
    if status
        b = 0;
        msg = response;
        error(msg);
    end

    if strcmp(mode,'local'), % download files

        if ~isfolder(filepath),
            mkdir(filepath);
        end;

        files = dataset.files;

        if verbose,
            disp(['Will download ' int2str(numel(files)) ' files...']);
        end

        files_map = containers.Map();

        for i = 1:numel(files)
            if verbose, disp(['Downloading file ' int2str(i) ' of ' int2str(numel(files))  ' (' num2str(100*(i)/numel(files))  '%)' '...']); end
            file_uid = files(i).uid;
            uploaded = files(i).uploaded;
            files_map(file_uid) = uploaded;
            if ~uploaded
                disp('not uploaded to the cloud. Skipping...')
                continue;
            end
            file_path = [output_path filesep 'download' filesep 'files' filesep file_uid];
            if isfile(file_path)
                if verbose, disp(['File ' int2str(i) ' already exists. Skipping...']); end
                continue;
            end
            [~, ~, downloadURL, ~] = ndi.cloud.api.datasets.get_files_detail(dataset_id, file_uid);
            if verbose, disp(['Saving file ' int2str(i) '...']); end

            % save the file
            websave(file_path, downloadURL);
        end
        if verbose, disp(['File Downloading complete.']); end
    end;


    if ~isfolder(jsonpath);
        mkdir(jsonpath);
    end


    if verbose, disp(['Will download ' int2str(numel(dataset.documents)) ' documents...']); end
    d = dataset.documents;

    for i = 1:numel(d)
        if verbose, disp(['Downloading document ' int2str(i) ' of ' int2str(numel(d))  ' (' num2str(100*(i)/numel(d))  '%)' '...']); end
        document_id = d{i};
        json_file_path = fullfile(jsonpath,[document_id '.json']);
        if isfile(json_file_path)
            if verbose, disp(['Document ' int2str(i) ' already exists. Skipping...']); end
            continue;
        end

        [status, response, docStruct] = ndi.cloud.api.documents.get_documents(dataset_id, document_id);
        if status
            b = 0;
            msg = response;
            error(msg);
        end
        if verbose, disp(['Saving document ' int2str(i) '...']); end

        docStruct = rmfield(docStruct, 'id');
        docStruct = ndi.cloud.download.set_file_info(docStruct,mode,filepath);

        document_obj = ndi.document(docStruct);
        % save the document in .json file
        did.file.str2text(json_file_path,did.datastructures.jsonencodenan(document_obj));
    end

    ndiDocuments = ndi.cloud.download.jsons2documents(jsonpath);

    if verbose, disp(['Building dataset from documents...']); end;
    if verbose & strcmp(mode,'local'), disp(['Will copy downloaded files into dataset..may take several minutes if the dataset is large...']); end;

    D = ndi.dataset.dir([],output_path,ndiDocuments);

