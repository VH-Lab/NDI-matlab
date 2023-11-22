%% datasets
% prefix = [userpath filesep 'Documents' filesep 'NDI']; 
% foldername = "/Users/cxy/Documents/NDI/2023-03-08/";
% filename = "/Users/cxy/Documents/NDI/2023-03-08/t*";
% % ls([foldername filesep 't*'])
% 
% S = ndi.session.dir("2023-03-08",[foldername]);
% 
% type (fullfile(filename,'t00001','stims.tsv'))

fileName = 'exampledataset.json'; 
str = fileread(fileName); 
example_dataset = jsondecode(str); 

[status, response, dataset_id] = ndi.cloud.datasets.post_organization(organizationId, example_dataset, auth_token);

update_dataset = example_dataset;
update_dataset.name = "updated example dataset";
[status, response] = ndi.cloud.datasets.post_datasetId(dataset_id, update_dataset, auth_token);
%example organization id: '645163735ea2a39cb644cc6c'
[status, response, datasets] = ndi.cloud.datasets.get_organizations(organization_id, auth_token);

[status, response] = ndi.cloud.datasets.delete_datasetId(dataset_id, auth_token);

[status, response, datasets] = ndi.cloud.datasets.get_organizations(organization_id, auth_token);
id = "64d4c79bbafd38dfb30b1824";
[status,dataset] = ndi.cloud.datasets.get_datasetId(dataset_id, auth_token);
[status, response, dataset_id] = ndi.cloud.datasets.post_organization(organizationId, example_dataset, auth_token);
[status,dataset] = ndi.cloud.datasets.get_datasetId(dataset_id, auth_token);
page = 1;
page_size = 1;
[status, response, datasets] = ndi.cloud.datasets.get_published(page, page_size, auth_token);
%% not successful
[status, response, datasets] = ndi.cloud.datasets.get_unpublished(page, page_size, auth_token);
curl -X PUT -T /path/to/local/file.jpg -H "Content-Type: image/jpeg" "https://presigned-url"

[status, response, url] = ndi.cloud.datasets.get_files_raw(dataset_id, uid, auth_token);
[status, output] = ndi.cloud.put_files(presigned_url, file_path, auth_token);
%example dataset id: '6466c110390dd305045ee10e'
%example document id: ''6466f7e9cd19dffd5f63022c'
[status, response, document] = ndi.cloud.documents.get_documents(dataset_id, document_id, auth_token);
all_docs = summary.documents;
all_docs_ids = all_docs.id;
[status, response, document] = ndi.cloud.documents.get_documents('6466c110390dd305045ee10e', all_docs(3).id, auth_token);
[status, response, summary] = ndi.cloud.documents.get_documents_summary(dataset_id, auth_token);

docName = 'exampledocument.json'; 
str_doc = fileread(docName); 
example_document = jsondecode(str_doc); 
[status, response] = ndi.cloud.documents.post_documents(dataset_id, example_document, auth_token);
