function test_nsd_datatree
% TEST_DATATREE - A test function for the nsd_datatree class
%
%   Creates an experiment based on a test directory in vhtools_mltbx_toolsbox.
%   Then it finds the number of epochs and returns the files associated with epoch N=2.
%
%   

mydirectory = [userpath filesep 'tools' filesep 'vhlab_mltbx_toolbox' ...
 		filesep 'directory' filesep 'test_dirs' filesep 'findfilegroupstest3'];

exp = nsd_experiment_dir('myexperiment',mydirectory);

dt = nsd_datatree(exp, {'myfile_#.ext1','myfile_#.ext2'});

n = numepochs(dt);

disp(['Number of epochs are ' num2str(n) '.']);

disp(['File paths of epoch 2 are as follows: ']);

f = getepochfiles(dt,2),

disp(['the nsd_datatree object fields:'])

dt,

