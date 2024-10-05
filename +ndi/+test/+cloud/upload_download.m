function [b,msg] = upload_download(D,metadatafile)
% UPLOAD_DOWNLOAD - test uploading and downloading an example dataset
%
% [B,MSG] = UPLOAD_DOWNLOAD([D,metadatafile])
%
% Test uploading and then downloading an example ndi.dataset D.
%

if nargin<1,
	dirname = fullfile(ndi.common.PathConstants.ExampleDataFolder, '..' ,'example_datasets', 'sample_test');
	D = ndi.dataset.dir(dirname);
	metadatafile = fullfile(ndi.common.PathConstants.ExampleDataFolder,'..',...
		'example_datasets','NDIDatasetUpload','metadata.mat');
end;

metadata = load(metadatafile);
datasetInformation = metadata.datasetInformation;
metadata_json = ndi.cloud.fun.metadata_to_json(datasetInformation);

b = 0;

 % step 1: upload

tic;

[status, response, dataset_id] = ndi.cloud.api.datasets.post_organization(metadata_json);
if status,
	msg=['ndi.cloud.api.datasets.post_organization() failed to create a new dataset' response];
	return;
end;

[b_upload, msg_upload] = ndi.database.fun.upload_to_NDI_cloud(D, dataset_id);

if ~b_upload,
	msg = msg_upload;
	return;
end;

time_taken = toc;

disp(['Upload finished in ' num2str(time_taken) '.']);

 % Step 2: download

newdir = ndi.file.temp_name;

mkdir(newdir);

disp(['Pausing 10 seconds to let the remote catch up...']);

pause(10);

tic;

[b_download,msg_download] = ndi.cloud.download_dataset(dataset_id,newdir);

if ~b_download,
	msg = msg_download;
	return;
end;

time_taken = toc;

disp(['Download finished in ' num2str(time_taken) '.']);

D1 = D;
D2 = ndi.dataset.dir(newdir);

disp(['Comparing datasets']);
[b,msg] = ndi.test.dataset.compare(D1,D2);

disp('All finished, now deleting the temporary directory...');

rmdir(newdir,'s');

