[status, response, upload_url] = ndi.cloud.api.files.get_raw_file_upload_url(dataset_id, uid);

file_path = '/Users/cxy/Documents/MATLAB/tools/NDI-matlab/+ndi/+cloud/41268d7e0d7a972b_c0c66ea66e3f90ae';
[status, output] = ndi.cloud.put_files(upload_url, file_path);

directoryPath = '/Users/cxy/Documents/MATLAB/data/2021-04-01/.ndi/json';
largerFiles = ndi.cloud.plotJsonFileSizes(directoryPath);
