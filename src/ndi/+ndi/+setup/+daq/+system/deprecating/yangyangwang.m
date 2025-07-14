function S = yangyangwang(S, daqsystemname)
    % ndi.setup.daq.system.yangyangwang - initialize daq systems used by VHLAB
    %
    % S = ndi.setup.daq.system.yangyangwang(S, DEVNAME)
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
    % | yangyang_tdt_sev | ndi.daq.system.mfdaq that looks for files        |
    % |                  |    '*_Ch1.sev'                                   |
    % -----------------------------------------------------------------------
    %
    % See also: ndi.file.navigator.epochdir

    if nargin == 0
        S = {'yangyang_tdt_sev'};
        return;
    end

    if iscell(daqsystemname)
        for i=1:length(daqsystemname)
            S = ndi.setup.daq.system.yangyangwang(S, daqsystemname{i});
        end
        return;
    end

    epochprobemapclass = 'ndi.epoch.epochprobemap_daqsystem';

    switch daqsystemname
        case 'yangyang_tdt_sev'
            fileparameters = {'.*_Ch1\.sev\>','Notes.txt','StoresListing.txt','probemap.txt'};
            readerobjectclass = ['ndi.daq.reader.mfdaq.ndr(''SEV'') '];
            epochprobemapfileparameters = {'probemap.txt'};
            mdr = {};
        otherwise
            error(['Unknown device requested ' daqsystemname '.']);
    end

    ft = ndi.file.navigator.epochdir(S, fileparameters, epochprobemapclass, epochprobemapfileparameters);

    eval(['dr = ' readerobjectclass ';']);

    mydev = ndi.daq.system.mfdaq(daqsystemname, ft, dr, mdr); % create the daq system object
    S = S.daqsystem_add(mydev); % add the daq system object to our ndi.session
