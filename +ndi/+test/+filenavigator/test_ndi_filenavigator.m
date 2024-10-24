function test_ndi_filenavigator
    % TEST_FILENAVIGATOR - A test function for the ndi_filenavigator class
    %
    %   Creates an session based on a test directory in vhtools_mltbx_toolsbox.
    %   Then it finds the number of epochs and returns the files associated with epoch N=2.
    %
    %

    mydirectory = [userpath filesep 'tools' filesep 'vhlab-toolbox-matlab' ...
        filesep 'file' filesep 'test_dirs' filesep 'findfilegroupstest3'];

    disp(['Working on directory ' mydirectory '...'])

    ls(mydirectory)

    exp = ndi.session.dir('mysession',mydirectory);

    ft = ndi.file.navigator(exp, {'myfile_#.ext1','myfile_#.ext2'});

    n = numepochs(ft);

    disp(['Number of epochs are ' num2str(n) '.']);

    disp(['File paths of epoch 2 are as follows: ']);

    f = getepochfiles(ft,2),

    disp(['the ndi.file.navigator object fields:'])

    ft,

    et = epochtable(ft);

    disp(['The epoch table entries:']);

    for i=1:numel(et),
        et(i),
    end

    disp(['File paths of epoch ' et(2).epoch_id ' are as follows: ']);

    f = getepochfiles(ft,et(2).epoch_id),
