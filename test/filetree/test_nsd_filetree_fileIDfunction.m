function [fileName,fileID] = test_nsd_filetree_fileIDfunction
% function: Short description
%
% Extended description

nsd_globals;
example_directory = [nsdpath filesep 'example_experiments'];
input_dir_name = [example_directory filesep 'exp_image_tiffstack' filesep 'raw_data' ];
example_exp = nsd_experiment_dir('exp1',input_dir_name);
%creating a new filetree that looks for .tif files.
example_filetree = nsd_filetree(example_exp,'.*\.tif\>');
[fileName,fileID] = example_filetree.getepochfiles;

end  % function
