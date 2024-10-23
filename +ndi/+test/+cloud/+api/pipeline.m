function pipeline()
    %PIPELINE - Pipeline for testing the cloud API

    dataset_id = ndi.test.cloud.api.upload_sample_test();
    ndi.test.cloud.api.post_documents_test(dataset_id);
    ndi.test.cloud.api.delete_documents_test(dataset_id);
    ndi.test.cloud.api.submit_publish_dataset(dataset_id);

    % for now, don't run branch test
    % ndi.test.cloud.api.dataset_branch_test(dataset_id);

end

