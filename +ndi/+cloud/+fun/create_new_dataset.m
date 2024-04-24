function [b, msg, dataset_id] = create_new_dataset(S, struct, email, password)
%CREATE_NEW_DATASET A helper function. Creates a new dataset filling the dataset details
%   using the dataset information collected from the metadata app, and add the openminds_doc
%   to the session. Finally, it uploads all the documents and files to the dataset.
%   Detailed explanation goes here
%
% [B, MSG, DATASET_ID] = ndi.cloud.fun.CREATE_NEW_DATASET(S, STRUCT, EMAIL, PASSWORD)
% 
% Inputs:
%   S - ndi.session object
%   STRUCT - a struct collected from the metadata app
%   EMAIL - email address of the user
%   PASSWORD - password of the user
%
% Outputs:
%   B - did the upload work? 0 for no, 1 for yes
%   MSG - An error message if the upload failed; otherwise ''
%   DATASET_ID - the dataset id of the newly created dataset

[status, response, dataset_id] = ndi.cloud.create_cloud_metadata_struct(struct);
% dataset_id = '65b2e807f75422c1b570d1b4';
d_openminds = S.database_search( ndi.query('openMinds.fields','hasfield'));
%remove all the old openminds docs
S = S.database_rm(d_openminds);
%add the new openminds doc
convertedDocs = ndi.database.metadata_app.convertFormDataToDocuments(struct);
S = S.database_add(convertedDocs);
[b, msg] = ndi.database.fun.upload_to_NDI_cloud(S, email, password, dataset_id);
end

