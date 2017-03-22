%% all the test for intan daq

dir_name = '';


test_intan_flat(dirname);


exp = NSD_device('exp');
 
%    under this method, the sATI_vhintan would have to query the experiment to identify the files to read

dev1 = sATI_vhintan('name', exp);


parentdirname = '';

%    under this method, the sATI_vhintan would have to query the parent directory to identify the files to read

dev2 = sATI_vhintan('name',parentdirname);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




