function url = url(type, varargin)
%URL - a function that returns the URL for the api
% 
% [URL] = ndi.cloud.api.URL(TYPE) returns the URL for the api
site = 'https://dev-api.ndi-cloud.com/v1/';
did.datastructures.assign(varargin{:});

if (strcmp(type,'login'))
    url = strcat(site, 'auth/login');
elseif (strcmp(type,'confirmation_resend'))
    url = strcat(site, 'auth/confirmation/resend');
elseif (strcmp(type,'logout'))
    url = strcat(site, 'auth/logout');
elseif (strcmp(type,'password'))
    url = strcat(site, 'auth/password');
elseif (strcmp(type,'password_forgot'))
    url = strcat(site, 'auth/password/forgot');
elseif (strcmp(type,'verify'))
    url = strcat(site, 'auth/verify');
elseif (strcmp(type,'delete_datasetId'))
    url = strcat(site, 'datasets/', dataset_id);
elseif (strcmp(type,'get_branches'))
    url = strcat(site, 'datasets/', dataset_id, '/branches');
elseif (strcmp(type,'get_files_detail'))
    url = strcat(site, 'datasets/', dataset_id, '/files/', uid, '/detail');
elseif (strcmp(type,'get_datasetId'))
    url = strcat(site, 'datasets/', dataset_id);
elseif (strcmp(type,'get_files'))
    url = strcat(site, 'datasets/', dataset_id, '/files/', uid);
elseif (strcmp(type,'get_files_raw'))
    url = strcat(site, 'datasets/', dataset_id, '/files/raw/', uid);
elseif (strcmp(type,'get_organizations'))
    url = strcat(site, 'organizations/', organization_id, '/datasets');
elseif (strcmp(type,'get_published'))
    url = strcat(site, 'datasets/published?page=', page, '&pageSize=', page_size);
elseif (strcmp(type,'get_unpublished'))
    url = strcat(site, 'datasets/unpublished?page=', page, '&pageSize=', page_size);
elseif (strcmp(type,'post_branch'))
    url = strcat(site, 'datasets/', dataset_id, '/branch');
elseif (strcmp(type,'post_bulk_delete'))
    url = strcat(site, 'datasets/', dataset_id, '/documents/bulk-delete');
elseif (strcmp(type,'post_datasetId'))
    url = strcat(site, 'datasets/', dataset_id);
elseif (strcmp(type,'post_organization'))
    url = strcat(site, 'organizations/', organization_id, '/datasets');
elseif (strcmp(type,'post_publish'))
    url = strcat(site, 'datasets/', dataset_id, '/publish');
elseif (strcmp(type,'post_submit'))
    url = strcat(site, 'datasets/', dataset_id, '/submit');
elseif (strcmp(type,'post_unpublish'))
    url = strcat(site, 'datasets/', dataset_id, '/unpublish');
elseif (strcmp(type,'delete_documents'))
    url = strcat(site, 'datasets/', dataset_id, '/documents/', document_id);
elseif (strcmp(type,'get_documents'))
    url = strcat(site, 'datasets/', dataset_id, '/documents/', document_id);
elseif (strcmp(type,'get_documents_summary'))
    url = strcat(site, 'datasets/', dataset_id, '/documents');
elseif (strcmp(type,'post_documents'))
    url = strcat(site, 'datasets/', dataset_id, '/documents');
elseif (strcmp(type,'post_documents_update'))
    url = strcat(site, 'datasets/', dataset_id, '/documents/', document_id);
elseif (strcmp(type, 'get_dataset_details'))
    url = strcat(site, 'datasets/', dataset_id, '/files/', uid, '/detail');
elseif (strcmp(type, 'get_files_bulk'))
    url = strcat(site, 'datasets/', dataset_id, '/files/bulk');
end

