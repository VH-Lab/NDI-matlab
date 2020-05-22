function [fileName,fileID] = test_ndi_filenavigator_fileIDfunction
% function: Short description
%
% Extended description

ndi_globals;
example_directory = [ndiexampleexperpath];
input_dir_name = [example_directory filesep 'exp_image_tiffstack' filesep 'raw_data' ];
example_exp = ndi_session_dir('exp1',input_dir_name);
%creating a new filenavigator that looks for .tif files.
example_filenavigator = ndi_filenavigator(example_exp,'.*\.tif\>');
[fileName,fileID] = example_filenavigator.getepochfiles;

end  % function
