function [b,msg] = upload_dataset(D,metadatafile)
% UPLOAD_DATASET - upload a local dataset to NDI-Cloud
%
% [B,MSG] = UPLOAD_DATASET(D,metadatafile)
%
% Upload the dataset D with metadata saved as METADATAFILE
%

metadata = load(metadatafile);
datasetInformation = metadata.datasetInformation;
metadata_json = ndi.cloud.fun.metadata_to_json(datasetInformation);

b = 0;

[status, response, dataset_id] = ndi.cloud.api.datasets.post_organization(metadata_json);
if status,
	msg=['ndi.cloud.api.datasets.post_organization() failed to create a new dataset' response];
	return;
end;

[b, msg] = ndi.database.fun.upload_to_NDI_cloud(D, dataset_id);


