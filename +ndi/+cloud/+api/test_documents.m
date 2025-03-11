
test_dataset_id = '645164a95ea2a39cb644cc71';
[status, response, summary] = ndi.cloud.api.documents.list_dataset_documents(dataset_id);
document_id = summary.documents.id;
docName = 'exampledocument.json';
str_doc = fileread(docName);
example_document = jsondecode(str_doc);
[status, response] = ndi.cloud.api.documents.update_document(dataset_id, document_id, example_document);

docName = '41268d7e0d7a3d86_c0d7e2ce1ad7d0af.json';
str_doc = fileread(docName);
example_document = jsondecode(str_doc);

docName = 'exampledocument.json';
str_doc = fileread(docName);
example_document = struct("name", "example document");
example_document = jsonencode(example_document);
[status, response, document_id] = ndi.cloud.api.documents.add_document(docName, dataset_id, example_document);uid = response.files.file_info.locations.uid;

document_id = '64e7d4694724787310421737';
[status, response, document] = ndi.cloud.api.documents.get_documents(dataset_id, document_id);
