function S = vhlab(S, daqsystemname)
    % ndi.setup.daq.system.vhlab - initialize daq systems used by VHLAB
    %
    % S = ndi.setup.daq.system.vhlab(S, DEVNAME)
    %
    % Creates daq systems that look for files in the VHLAB standard recording
    % scheme, where data from different epochs are organized into
    % subdirectories (using ndi.file.navigator.epochdir). DEVNAME should be the
    % name a daq systems in the table below. These daq systems are added to the ndi.session
    % object S. If DEVNAME is a cell list of strings, then multiple items are added.
    %
    % If the function is called with no input arguments, then it returns a list
    % of all valid device names.
    %
    % Each epoch is defined by the presence of a 'reference.txt' file, as well
    % as specific files that are needed by each device as described below.
    %
    %  Devices created   | Description
    % |------------------|--------------------------------------------------|
    % | vhintan          | ndi.daq.system.mfdaq that looks for files        |
    % |                  |    'vhintan_channelgrouping.txt' and '*.rhd'     |
    % | vhspike2         |    ndi.daq.system.mfdaq that looks for files     |
    % |                  |    'vhspike2_channelgrouping.txt' and '*.smr'    |
    % | vhvis_spike2     | ndi.daq.system.mfdaq.stimulus that looks for     |
    % |                  |    files 'stimtimes.txt', 'verticalblanking.txt',|
    % |                  |    'stims.mat', and 'spike2data.smr'.            |
    % -----------------------------------------------------------------------
    %
    % See also: ndi.file.navigator.epochdir

    if nargin == 0
        S = {'vhintan', 'vhspike2', 'vhvis_spike2'};
        return;
    end

    if iscell(daqsystemname)
        for i=1:length(daqsystemname)
            S = ndi.setup.daq.system.vhlab(S, daqsystemname{i});
        end
        return;
    end

    % all of our daq systems use this custom epochprobemap class
    epochprobemapclass = 'ndi.setup.epoch.epochprobemap_daqsystem_vhlab';

    switch daqsystemname
        case 'vhintan'
            fileparameters = {'reference.txt','.*\.rhd\>','vhintan_channelgrouping.txt','vhintan_intan2spike2time.txt'};
            readerobjectclass = ['ndi.daq.reader.mfdaq.intan'];
            epochprobemapfileparameters = {'vhintan_channelgrouping.txt'};
            mdr = {};
        case 'vhspike2'
            fileparameters = {'reference.txt', '.*\.smr\>', 'vhspike2_channelgrouping.txt'};
            readerobjectclass = ['ndi.daq.reader.mfdaq.cedspike2'];
            epochprobemapfileparameters = {'vhspike2_channelgrouping.txt'};
            mdr = {};
        case 'vhvis_spike2'
            fileparameters = {'reference.txt', 'stimtimes.txt', 'verticalblanking.txt',...
                'stims.mat', 'spike2data.smr'};
            readerobjectclass = ['ndi.setup.daq.reader.mfdaq.stimulus.vhlabvisspike2'];
            epochprobemapfileparameters = {'stimtimes.txt'};
            mdr = {ndi.daq.metadatareader.NewStimStims('stims.mat')};
        otherwise
            error(['Unknown device requested ' daqsystemname '.']);
    end

    ft = ndi.file.navigator.epochdir(S, fileparameters, epochprobemapclass, epochprobemapfileparameters);

    eval(['dr = ' readerobjectclass '();']);

    mydev = ndi.daq.system.mfdaq(daqsystemname, ft, dr, mdr); % create the daq system object
    S = S.daqsystem_add(mydev); % add the daq system object to our ndi.session
