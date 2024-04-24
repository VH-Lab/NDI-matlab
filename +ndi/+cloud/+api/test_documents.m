
test_dataset_id = '645164a95ea2a39cb644cc71';
[status, response, summary] = ndi.cloud.api.documents.get_documents_summary(dataset_id);
document_id = summary.documents.id;
docName = 'exampledocument.json'; 
str_doc = fileread(docName); 
example_document = jsondecode(str_doc); 
[status, response] = ndi.cloud.api.documents.post_documents_update(dataset_id, document_id, example_document);

docName = '41268d7e0d7a3d86_c0d7e2ce1ad7d0af.json'; 
str_doc = fileread(docName); 
example_document = jsondecode(str_doc); 
[status, response] = ndi.cloud.api.documents.post_documents(dataset_id, example_document);
uid = response.files.file_info.locations.uid;

document_id = '64e7d4694724787310421737';
[status, response, document] = ndi.cloud.api.documents.get_documents(dataset_id, document_id);