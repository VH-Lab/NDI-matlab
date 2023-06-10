[status, response, upload_url] = ndi.cloud.files.get_files_raw(dataset_id, uid, auth_token);

file_path = '/Users/cxy/Documents/MATLAB/tools/NDI-matlab/+ndi/+cloud/41268d7e0d7a972b_c0c66ea66e3f90ae';
[status, output] = ndi.cloud.put_files(upload_url, file_path, auth_token);