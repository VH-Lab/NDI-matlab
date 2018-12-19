function multiple_epoch_directory = test_nsd_iodevice_image_tiffstack_multipleepoch()
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here
nsd_globals;
example_directory = [nsdexampleexppath];
input_dir_name = [example_directory filesep 'exp_image_tiffstack' filesep 'raw_data' ];
example_exp = nsd_experiment_dir('exp1',input_dir_name);
example_filetree = nsd_filetree(example_exp,'.*\.tif\>');
example_device = nsd_iodevice_image_tiffstack('sampleDevice',example_filetree);
multiple_epoch_directory = example_device.epochfiles_dir;
