function [fileName,fileID] = test_ndi_filetree_fileIDfunction
% function: Short description
%
% Extended description

ndi_globals;
example_directory = [ndiexampleexperpath];
input_dir_name = [example_directory filesep 'exp_image_tiffstack' filesep 'raw_data' ];
example_exp = ndi_experiment_dir('exp1',input_dir_name);
%creating a new filetree that looks for .tif files.
example_filetree = ndi_filetree(example_exp,'.*\.tif\>');
[fileName,fileID] = example_filetree.getepochfiles;

end  % function
