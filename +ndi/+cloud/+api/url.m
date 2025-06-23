function url = url(endpointName, options)
    %URL - a function that returns the URL for a named api endpoint
    %
    % URL = ndi.cloud.api.URL(TYPE) returns the URL for the api
    
    arguments
        endpointName (1,1) string
        options.dataset_id (1,1) string = ""
        options.user_id (1,1) string = ""
        options.document_id (1,1) string = ""
        options.file_uid (1,1) string = ""
        options.organization_id (1,1) string = ""
        options.page (1,1) double = 1
        options.page_size (1,1) double = 20
    end
    options = processOptions(options);

    apiEnvironment = getenv('CLOUD_API_ENVIRONMENT');
    if isempty(apiEnvironment)
        apiEnvironment = 'prod';
    end

    switch apiEnvironment
        case 'prod'
            apiBaseUrl = "https://api.ndi-cloud.com/v1";
        case 'dev'
            apiBaseUrl = "https://dev-api.ndi-cloud.com/v1";
        otherwise
            error('NDICloud:GetURL:UnknownApiEnvironment', ...
                'Expected value for cloud api environment to be `prod` or `dev`, but got %s instead.', apiEnvironment)
    end
    
    persistent endpointMap
    if isempty(endpointMap)
        try
            endpointMap = dictionary();
        catch
            endpointMap = containers.Map("KeyType", "char", "ValueType", "char");
        end
        endpointMap("login")                          = "/auth/login";
        endpointMap("logout")                         = "/auth/logout";
        endpointMap("resend_confirmation")            = "/auth/confirmation/resend";
        endpointMap("verify_user")                    = "/auth/verify";
        endpointMap("change_password")                = "/auth/password";
        endpointMap("reset_password")                 = "/auth/password/forgot";
        endpointMap("set_new_password")               = "/auth/password/confirm";
        endpointMap("create_user")                    = "/users";
        endpointMap("get_user")                       = "/users/{userId}";
        endpointMap("get_dataset")                    = "/datasets/{datasetId}";
        endpointMap("update_dataset")                 = "/datasets/{datasetId}";
        endpointMap("delete_dataset")                 = "/datasets/{datasetId}";
        endpointMap("list_datasets")                  = "/organizations/{organizationId}/datasets";
        endpointMap("create_dataset")                 = "/organizations/{organizationId}/datasets";
        endpointMap("get_published")                  = "/datasets/published?page={page}&pageSize={page_size}";
        endpointMap("get_unpublished")                = "/datasets/unpublished?page={page}&pageSize={page_size}";
        endpointMap("get_raw_file_upload_url")        = "/datasets/{datasetId}/files/raw/{uid}";
        endpointMap("get_file_upload_url")            = "/datasets/{datasetId}/files/{uid}";
        endpointMap("get_file_collection_upload_url") = "/datasets/{datasetId}/files/bulk";
        endpointMap("get_file_details")               = "/datasets/{datasetId}/files/{uid}/detail";
        endpointMap("create_dataset_branch")          = "/datasets/{datasetId}/branch";
        endpointMap("get_branches")                   = "/datasets/{datasetId}/branches";
        endpointMap("submit_dataset")                 = "/datasets/{datasetId}/submit";
        endpointMap("publish_dataset")                = "/datasets/{datasetId}/publish";
        endpointMap("unpublish_dataset")              = "/datasets/{datasetId}/unpublish";
        endpointMap("get_document")                   = "/datasets/{datasetId}/documents/{documentId}";
        endpointMap("update_document")                = "/datasets/{datasetId}/documents/{documentId}";
        endpointMap("delete_document")                = "/datasets/{datasetId}/documents/{documentId}";
        endpointMap("bulk_delete_documents")          = "/datasets/{datasetId}/documents/bulk-delete";
        endpointMap("bulk_upload_documents")          = "/datasets/{datasetId}/documents/bulk-upload";
        endpointMap("bulk_download_documents")        = "/datasets/{datasetId}/documents/bulk-download";
        endpointMap("list_dataset_documents")         = "/datasets/{datasetId}/documents";
        endpointMap("add_document")                   = "/datasets/{datasetId}/documents";
        endpointMap("search_datasets")                = "/datasets/search";
    end

    endpointPath = endpointMap(endpointName);

    tokens = regexp(endpointPath, '\{([^}]+)\}', 'tokens'); % Capture path names
    tokens = [tokens{:}];

    for i = 1:numel(tokens)
        try
            endpointPath = replacePathParameter(endpointPath, tokens{i}, options);
        catch
            throwAsCaller( getMissingParameterException(tokens{i}, endpointName) )
        end
    end

    url = matlab.net.URI( apiBaseUrl + endpointPath );
end

function endpointPath = replacePathParameter(endpointPath, parameterName, params)
    parameterValue = params.(parameterName);
    if isstring(parameterValue)
        assert(~isempty( char(parameterValue) ))
    elseif isnumeric(parameterValue)
        parameterValue = sprintf('%d', parameterValue);
    end
    endpointPath = strrep(endpointPath, sprintf('{%s}', parameterName), parameterValue);
end

function options = processOptions(options)
    % Todo: Should not be necessary
    options = renameStructField(options, 'file_uid', 'uid');
    options = renameStructField(options, 'dataset_id', 'datasetId');
    options = renameStructField(options, 'document_id', 'documentId');
    options = renameStructField(options, 'organization_id', 'organizationId');
    options = renameStructField(options, 'user_id', 'userId');
    options = renameStructField(options, 'page_size', 'pageSize');

    function s = renameStructField(s, oldname, newname)
        s.(newname) = s.(oldname);
    end
end

function ME = getMissingParameterException(parameterName, endpointName)
    ME = MException(...
        'NDI:CloudApiUrl:MissingPathParameter', ...
        '"%s" is a required parameter for the "%s" endpoint', parameterName, endpointName);
end
