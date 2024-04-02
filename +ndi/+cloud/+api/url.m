function url = url(type, varargin)
%URL - a function that returns the URL for the api
% 
% [URL] = ndi.cloud.api.URL(TYPE) returns the URL for the api
site = 'https://dev-api.ndi-cloud.com/v1/';
did.datastructures.assign(varargin{:});

if (type == 'login')
    url = strcat(site, 'auth/login');
elseif (type == 'confirmation_resend')
    url = strcat(site, 'auth/confirmation/resend');
elseif (type == 'logout')
    url = strcat(site, 'auth/logout');
elseif (type == 'password')
    url = strcat(site, 'auth/password');
elseif (type == 'password_forgot')
    url = strcat(site, 'auth/password/forgot');
elseif (type == 'verify')
    url = strcat(site, 'auth/verify');
elseif (type == 'delete_datasetId')
    url = strcat(site, 'datasets/', dataset_id);
elseif (type == 'get_branches')
    url = strcat(site, 'datasets/', dataset_id, '/branches');
elseif (type == 'get_datasetId')
    url = strcat(site, 'datasets/', dataset_id);
elseif (type == 'get_files')
    url = strcat(site, 'datasets/', dataset_id, '/files/', uid);
elseif (type == 'get_files_raw')
    url = strcat(site, 'datasets/', dataset_id, '/files/raw/', uid);
elseif (type == 'get_organizations')
    url = strcat(site, 'organizations/', organization_id, '/datasets');
elseif (type == 'get_published')
    url = strcat(site, 'datasets/published?page=', page, '&pageSize=', page_size);
elseif (type == 'get_unpublished')
    url = strcat(site, 'datasets/unpublished?page=', page, '&pageSize=', page_size);
elseif (type == 'post_branch')
    url = strcat(site, 'datasets/', dataset_id, '/branch');
elseif (type == 'post_bulk_delete')
    url = strcat(site, 'datasets/', dataset_id, '/documents/bulk-delete');
elseif (type == 'post_datasetId')
    url = strcat(site, 'datasets/', dataset_id);
elseif (type == 'post_organization')
    url = strcat(site, 'organizations/', organization_id, '/datasets');
elseif (type == 'post_publish')
    url = strcat(site, 'datasets/', dataset_id, '/publish');
elseif (type == 'post_submit')
    url = strcat(site, 'datasets/', dataset_id, '/submit');
elseif (type == 'post_unpublish')
    url = strcat(site, 'datasets/', dataset_id, '/unpublish');
elseif (type == 'delete_documents')
    url = strcat(site, 'datasets/', dataset_id, '/documents/', document_id);
elseif (type == 'get_documents')
    url = strcat(site, 'datasets/', dataset_id, '/documents', document_id);
elseif (type == 'get_documents_summary')
    url = strcat(site, 'datasets/', dataset_id, '/documents');
elseif (type == 'post_documents')
    url = strcat(site, 'datasets/', dataset_id, '/documents');
elseif (type == 'post_documents_update')
    url = strcat(site, 'datasets/', dataset_id, '/documents/', document_id);
end

