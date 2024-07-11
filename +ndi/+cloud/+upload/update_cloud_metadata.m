function [status, dataset] = update_cloud_metadata(datasetid, S)
% UPDATE_CLOUD_METADATA - upload metadata to the NDI Cloud
%
% [STATUS, DATASET] = ndi.cloud.upload.UPDATE_CLOUD_METADATA(DATASETID, S)
%
% Inputs:
%   DATASETID - the dataset ID to update
%   S - an ndi.session object with the metadata to upload
%
% Outputs:
%   STATUS - did the upload work? 0 for no, 1 for yes
%   DATASET - The updated dataset
%

% loops over all the metadata fields and posts an updated value to the cloud API

all_fields = {'name','branchName','contributors','doi','funding','abstract','license','species','numberOfSubjects','correspondingAuthors'};
d_datasetVersion = S.database_search(ndi.query('openminds.openminds_type','contains_string', 'DatasetVersion'));
d_authors = S.database_search(ndi.query('openminds.openminds_type','contains_string', 'Person'));
clear dataset_update;

dataset_update.name = d_datasetVersion{1}.document_properties.openminds.fields.fullName;
dataset_update.branchName = "original submission";
dataset_update.doi = "https://doi.org://10.1000/123456789";
dataset_update.abstract = d_datasetVersion{1}.document_properties.openminds.fields.description;
author_struct = struct();
for i = 1:numel(d_authors)
    author_struct(i).firstName = d_authors{i}.document_properties.openminds.fields.givenName;
    author_struct(i).lastName = d_authors{i}.document_properties.openminds.fields.familyName;
    identifier_ndi = d_authors{i}.document_properties.openminds.fields.digitalIdentifier{1};
    %remove the prefix ndi://from the identifier
    identifier_ndi = identifier_ndi(7:end);
    d_identifier = S.database_search(ndi.query('base.id','contains_string', identifier_ndi));
    author_struct(i).orchid = d_identifier{1}.document_properties.openminds.fields.identifier;
end
dataset_update.contributors = author_struct;

 
[status,dataset] = ndi.cloud.api.datasets.post_datasetId(datasetid,dataset_update);
end

