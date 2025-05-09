function test_ndi_daqsystem_image_tiffstack( input_file_directory )
    %UNTITLED5 Summary of this function goes here
    %   Detailed explanation goes here

    global epoch_number frame_number;
    epoch_number = 1;
    % The epoch to be tested by both .frame(n,i), and .numFrame(n). Could be changed for testing.
    frame_number = 1;
    % the frame to be taken using .frame(n,i) function. Could be changed for testing

    % Makes sure that the input_file_directory argument is indeed a directory,
    % and that only one arguments is passed.
    % If no argument is passed, then set the directories to a
    % default.
    if nargin < 1
        example_directory = [ndi.common.PathConstants.ExampleDataFolder];
        input_dir_name = [example_directory filesep 'exp_image_tiffstack' filesep 'raw_data' ];
        output_dir_name = [example_directory filesep 'exp_image_tiffstack' filesep 'output' ];
        if exist(output_dir_name) ~=7
            mkdir(output_dir_name);
        end
    elseif exist(input_file_directory) ~= 7
        error('argument is not a directory');
    else
        parent_dir = fileparts(input_file_directory);
        output_dir_name = [parent_dir filesep 'output'];
        mkdir(output_dir_name);
    end

    % creating a new session object
    example_exp = ndi.session.dir('exp1',input_dir_name);
    % creating a new filenavigator that looks for .tif files.
    example_filenavigator = ndi.file.navigator(example_exp,'.*\.tif\>');
    % creating an image_tiffstack daqsystem object
    example_device = ndi.daq.system.image.tiffstack('sampleDevice',example_filenavigator);

    disp('Counting the number of frames in the first epoch');
    disp(['The first epoch has ' num2str(example_device.numFrame(epoch_number)) ' frames']);

    disp(['Collecting frame number ' num2str(frame_number) ' from epoch number ' num2str(epoch_number)]);
    image = example_device.frame(epoch_number,frame_number);
    imwrite(image, [output_dir_name filesep 'example_frame.tif']);
    disp(['frame exported to "' output_dir_name '"']);

    disp('Testing cache functionality...');
    disp('Counting the number of frames in the first epoch');
    disp(['The first epoch has ' num2str(example_device.numFrame(epoch_number)) ' frames']);

    disp(['Collecting frame number ' num2str(frame_number) ' from epoch number ' num2str(epoch_number)]);
    image = example_device.frame(epoch_number,frame_number);
    imwrite(image, [output_dir_name filesep 'example_frame.tif']);
    disp(['frame exported to "' output_dir_name '"']);
end
