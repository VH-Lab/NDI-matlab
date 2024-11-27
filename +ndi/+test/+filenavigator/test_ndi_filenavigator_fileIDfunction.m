function [fileName,fileID] = test_ndi_filenavigator_fileIDfunction
    % function: Short description
    %
    % Extended description

    example_directory = [ndi.common.PathConstants.ExampleDataFolder];
    input_dir_name = [example_directory filesep 'exp_image_tiffstack' filesep 'raw_data' ];
    example_exp = ndi.session.dir('exp1',input_dir_name);
    % creating a new filenavigator that looks for .tif files.
    example_filenavigator = ndi.file.navigator(example_exp,'.*\.tif\>');
    [fileName,fileID] = example_filenavigator.getepochfiles;

end  % function
