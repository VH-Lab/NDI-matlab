function url = url(type, varargin)
    %URL - a function that returns the URL for the api
    %
    % [URL] = ndi.cloud.api.URL(TYPE) returns the URL for the api
    site = 'https://dev-api.ndi-cloud.com/v1/';
    vlt.data.assign(varargin{:});

    if (strcmp(type,'login'))
        url = strcat(site, 'auth/login');
    elseif (strcmp(type,'resend_confirmation'))
        url = strcat(site, 'auth/confirmation/resend');
    elseif (strcmp(type,'logout'))
        url = strcat(site, 'auth/logout');
    elseif (strcmp(type,'update_password'))
        url = strcat(site, 'auth/password');
    elseif (strcmp(type,'reset_password'))
        url = strcat(site, 'auth/password/forgot');
    elseif (strcmp(type,'verify_user'))
        url = strcat(site, 'auth/verify');
    elseif (strcmp(type,'delete_dataset'))
        url = strcat(site, 'datasets/', dataset_id);
    elseif (strcmp(type,'get_branches'))
        url = strcat(site, 'datasets/', dataset_id, '/branches');
    elseif (strcmp(type,'get_file_details'))
        url = strcat(site, 'datasets/', dataset_id, '/files/', uid, '/detail');
    elseif (strcmp(type,'get_dataset'))
        url = strcat(site, 'datasets/', dataset_id);
    elseif (strcmp(type,'get_file_upload_url'))
        url = strcat(site, 'datasets/', dataset_id, '/files/', uid);
    elseif (strcmp(type,'get_raw_file_upload_url'))
        url = strcat(site, 'datasets/', dataset_id, '/files/raw/', uid);
    elseif (strcmp(type,'list_datasets'))
        url = strcat(site, 'organizations/', organization_id, '/datasets');
    elseif (strcmp(type,'get_published'))
        url = strcat(site, 'datasets/published?page=', page, '&pageSize=', page_size);
    elseif (strcmp(type,'get_unpublished'))
        url = strcat(site, 'datasets/unpublished?page=', page, '&pageSize=', page_size);
    elseif (strcmp(type,'create_dataset_branch'))
        url = strcat(site, 'datasets/', dataset_id, '/branch');
    elseif (strcmp(type,'bulk_delete_documents'))
        url = strcat(site, 'datasets/', dataset_id, '/documents/bulk-delete');
    elseif (strcmp(type,'update_dataset'))
        url = strcat(site, 'datasets/', dataset_id);
    elseif (strcmp(type,'create_dataset'))
        url = strcat(site, 'organizations/', organization_id, '/datasets');
    elseif (strcmp(type,'publish_dataset'))
        url = strcat(site, 'datasets/', dataset_id, '/publish');
    elseif (strcmp(type,'submit_dataset'))
        url = strcat(site, 'datasets/', dataset_id, '/submit');
    elseif (strcmp(type,'unpublish_dataset'))
        url = strcat(site, 'datasets/', dataset_id, '/unpublish');
    elseif (strcmp(type,'delete_document'))
        url = strcat(site, 'datasets/', dataset_id, '/documents/', document_id);
    elseif (strcmp(type,'get_document'))
        url = strcat(site, 'datasets/', dataset_id, '/documents/', document_id);
    elseif (strcmp(type,'list_dataset_documents'))
        url = strcat(site, 'datasets/', dataset_id, '/documents');
    elseif (strcmp(type,'add_document'))
        url = strcat(site, 'datasets/', dataset_id, '/documents');
    elseif (strcmp(type,'update_document'))
        url = strcat(site, 'datasets/', dataset_id, '/documents/', document_id);
    elseif (strcmp(type, 'get_file_collection_upload_url'))
        url = strcat(site, 'datasets/', dataset_id, '/files/bulk');
    end
