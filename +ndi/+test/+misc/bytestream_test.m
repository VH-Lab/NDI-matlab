function b = bytestream_test
    % ndi.test.misc.bytestream_test - prepare a bytestream file for testing on multiple platforms
    %
    % b = ndi.test.misc.bytestream_test()
    %
    % Loads a file called 'bytestream.mat' in the current directory, and tests if the reconstruction
    % of the variables from the bytestream variable 'bytestream' exactly match the structure in
    % the variable 'bytestream_structure'.
    %
    % If the test passes, b is 1.
    %
    % See also: ndi.test.misc.bytestream_save
    %

    load bytestream.mat

    bytestream_structure_reconstruct = getArrayFromByteStream(bytestream);

    b = eqlen(bytestream_structure_reconstruct, bytestream_structure);
