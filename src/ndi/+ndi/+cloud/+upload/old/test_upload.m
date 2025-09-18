function [b, msg, dataset_id] = test_upload(S,test_name)
    %TEST_UPLOAD - upload a test dataset to the cloud
    % [B, MSG, DATASET_ID] = ndi.cloud.test_upload(S, TEST_NAME)
    %
    % inputs:
    %   S - ndi.session object
    %   TEST_NAME - the name of the test
    %
    % outputs:
    %   B - 1 if the upload was successful, 0 if not
    %   MSG - a message about the upload
    %   DATASET_ID - the dataset id of the uploaded dataset

    [auth_token, organization_id] = ndi.cloud.uilogin();
    d = struct('name',test_name);
    % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.create_dataset with ndi.cloud.api.datasets.createDataset
    [response, dataset_id] = ndi.cloud.api.datasets.create_dataset(d);
    [b, msg] = ndi.cloud.upload.upload_to_NDI_cloud(S, dataset_id);
end
