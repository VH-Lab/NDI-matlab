%% datasets
% prefix = [userpath filesep 'Documents' filesep 'NDI'];
% foldername = "/Users/cxy/Documents/NDI/2023-03-08/";
% filename = "/Users/cxy/Documents/NDI/2023-03-08/t*";
% % ls([foldername filesep 't*'])
%
% S = ndi.session.dir("2023-03-08",[foldername]);
%
% type (fullfile(filename,'t00001','stims.tsv'))

fileName = '/Users/cxy/Documents/MATLAB/tools/NDI-matlab/+ndi/+cloud/+api/exampledataset.json';
str = fileread(fileName);
example_dataset = jsondecode(str);

[status, response, dataset_id] = ndi.cloud.api.datasets.post_organization(example_dataset);

update_dataset = example_dataset;
update_dataset.name = "updated example dataset";
[status, response] = ndi.cloud.api.datasets.post_datasetId(dataset_id, update_dataset);
% example organization id: '645163735ea2a39cb644cc6c'
[status, response, datasets] = ndi.cloud.api.datasets.list_datasets(organization_id);

[status, response] = ndi.cloud.api.datasets.delete_dataset(dataset_id);

[status, response, datasets] = ndi.cloud.api.datasets.list_datasets(organization_id);
id = "64d4c79bbafd38dfb30b1824";
[status,dataset, response] = ndi.cloud.api.datasets.get_dataset(dataset_id);
[status, response, dataset_id] = ndi.cloud.api.datasets.post_organization(organizationId, example_dataset);
[status,dataset, response] = ndi.cloud.api.datasets.get_dataset(dataset_id);
page = 1;
page_size = 1;
[status, response, datasets] = ndi.cloud.api.datasets.get_published(page, page_size);
%% not successful
[status, response, datasets] = ndi.cloud.api.datasets.get_unpublished(page, page_size);
curl -X PUT -T /path/to/local/file.jpg -H "Content-Type: image/jpeg" "https://presigned-url"

[status, response, url] = ndi.cloud.api.datasets.get_raw_file_upload_url(dataset_id, uid);
[status, output] = ndi.cloud.put_files(presigned_url, file_path);
% example dataset id: '6466c110390dd305045ee10e'
% example document id: ''6466f7e9cd19dffd5f63022c'
[status, response, document] = ndi.cloud.api.documents.get_documents(dataset_id, document_id);
all_docs = summary.documents;
all_docs_ids = all_docs.id;
[status, response, document] = ndi.cloud.api.documents.get_documents('6466c110390dd305045ee10e', all_docs(3).id);
[status, response, summary] = ndi.cloud.api.documents.get_documents_summary(dataset_id);

docName = 'exampledocument.json';
str_doc = fileread(docName);
example_document = struct("name", "example document");
example_document = jsonencode(example_document);
[status, response, document_id] = ndi.cloud.api.documents.post_documents(docName, dataset_id, example_document);

[status, response] = ndi.cloud.api.datasets.post_unpublish(dataset_id);
[status, response] = ndi.cloud.api.datasets.post_publish(dataset_id);
