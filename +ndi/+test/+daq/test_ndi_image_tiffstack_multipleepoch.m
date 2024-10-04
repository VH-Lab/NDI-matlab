function multiple_epoch_directory = test_ndi_daqsystem_image_tiffstack_multipleepoch()
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here
ndi.globals;
example_directory = [ndi.common.PathConstants.ExampleDataFolder];
input_dir_name = [example_directory filesep 'exp_image_tiffstack' filesep 'raw_data' ];
example_exp = ndi.session.dir('exp1',input_dir_name);
example_filenavigator = ndi.file.navigator(example_exp,'.*\.tif\>');
example_device = ndi.daq.system.image.tiffstack('sampleDevice',example_filenavigator);
multiple_epoch_directory = example_device.epochfiles_dir;
