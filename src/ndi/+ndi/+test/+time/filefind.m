function filefind()

    % at present, this is not a user-accessible test function

    S = ndi.session.dir('/Volumes/van-hooser-lab/Users/steve/cf/2019-11-19')

    p = S.getprobes();

    d = S.daqsystem_load()

    [data,t,timeref] = p{1}.readtimeseries('t00002',20,30);

    [data_stim,t_stim,timeref_stim] = p{3}.readtimeseries(timeref,20,30);
