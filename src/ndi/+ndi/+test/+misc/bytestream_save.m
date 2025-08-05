function bytestream_save
    % ndi.test.misc.bytestream_save - prepare a bytestream file for testing on multiple platforms
    %
    % ndi.test.misc.bytestream_save()
    %
    % Creates a file called 'bytestream.mat' in the current directory.
    %
    % The file contains a variable 'bytestream' that is the bytestream conversion of
    % a structure 'bytestream_structure' that consists of a few Matlab variables, including a custom object
    % (an ndi.document).
    %
    % Upon loading the file, one can test that it works on that platform by running
    % ndi.test.misc.bytesream_test
    %
    % See also: ndi.test.misc.bytestream_test
    %

    bytestream_structure = struct( ...
        'a',rand(5,3,2),...
        'mydoc',ndi.document(),...
        'acell',{1, 2, 3}, ...
        'astring', ['this is a test' sprintf('\n')]);

    bytestream = getByteStreamFromArray(bytestream_structure);

    save bytestream.mat bytestream bytestream_structure
