function upload_sample_test()
% UPLOAD_SAMPLE_TEST - tests the api commands used to upload a sample dataset
%
% UPLOAD_SAMPLE_TEST()
%
% Tests the following api commands:
%    
%    datasets/get_datasetid
%    datasets/post_organization
%
%

ndi.globals;
dirname = [ndi_globals.path.exampleexperpath filesep '..' filesep 'example_datasets' filesep 'sample_test'];

D = ndi.dataset.dir(dirname);

metadatafile = [ndi_globals.path.exampleexperpath filesep '..' filesep 'example_datasets' filesep 'dataset.mat'];




