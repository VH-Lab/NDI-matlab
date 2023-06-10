
test_dataset_id = '645164a95ea2a39cb644cc71';
[status, response, summary] = ndi.cloud.documents.get_documents_summary(dataset_id, auth_token);
document_id = summary.documents.id;
docName = 'exampledocument.json'; 
str_doc = fileread(docName); 
example_document = jsondecode(str_doc); 
[status, response] = ndi.cloud.documents.post_documents_update(dataset_id, document_id, example_document, auth_token);

docName = '41268d7e0d7a3d86_c0d7e2ce1ad7d0af.json'; 
str_doc = fileread(docName); 
example_document = jsondecode(str_doc); 
[status, response] = ndi.cloud.documents.post_documents(dataset_id, example_document, auth_token);
uid = response.files.file_info.locations.uid;


[status, response, document] = ndi.cloud.documents.get_documents(dataset_id, document_id, auth_token);