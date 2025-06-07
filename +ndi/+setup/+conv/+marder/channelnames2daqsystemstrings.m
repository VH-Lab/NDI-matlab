function [name, ref, daqsysstr,subjectlist] = channelnames2daqsystemstrings(chNames, daqname, subjects, options)
    %
    % DAQSYSSTR = CHANNELNAMES2DAQSYSTEMSTRINGS(CHNAMES, DAQNAME, SUBJECTS)
    %
    %

    arguments
        chNames
        daqname
        subjects
        options.forceIgnore2 = false
        options.channelnumbers = []
    end

    name = {};
    ref = [];
    subjectlist = {};

    if isempty(options.channelnumbers)
        options.channelnumbers = 1:numel(chNames);
    end

    hasPhysio = 0;

    for i=1:numel(chNames)
        if i==1
            daqsysstr = ndi.daq.daqsystemstring(daqname, {'ai'}, options.channelnumbers(i));
        else
            daqsysstr(end+1) = ndi.daq.daqsystemstring(daqname, {'ai'}, options.channelnumbers(i));
        end
        [name{i},ref(i),subjectlist{i}] = ndi.setup.conv.marder.channelname2probename(chNames{i},subjects,...
            'forceIgnore2',options.forceIgnore2);
        if strcmp(name{i},'PhysiTemp_1')
            hasPhysio = options.channelnumbers(i);
        end
    end

    if hasPhysio & numel(subjects)>1 % add it to any second prep
        daqsysstr(end+1) = ndi.daq.daqsystemstring(daqname, {'ai'}, hasPhysio);
        name{end+1} = 'PhysiTemp_2';
        ref(i+1) = 1;
        subjectlist{end+1} = subjects{2};
    end
