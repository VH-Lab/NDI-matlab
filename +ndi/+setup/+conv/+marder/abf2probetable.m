function abf2probetable(S, options)
    % ABF2PROBETABLE - Populate a probetable table for a Marder ndi session
    %
    % ABF2PROBETABLE(S)
    %
    % Reads all ABF files in the NDI session S and creates a putative
    % probetable file.
    %
    % To create a new Marder lab session from a directory, use
    %  S = ndi.setup.lab('marderlab',REF,DIRNAME)
    %
    % It is necessary to first create a subject1.txt file with the subject
    % identifier of the first crab. If there are two crabs being recorded, then
    % it is necessary to create a subject2.txt file. And so on.
    %
    % The usual naming convention: 745_003_01@marderlab.brandeis.edu
    %  where 745 is the lab notebook, 003 is the experiment number in the
    %  lab notebook, and 01 indicates that there is only one prep in this
    %  experiment.
    %

    arguments
        S (1,1)
        options.forceIgnore2 = false
    end

    dirname = S.getpath();

    d = dir([dirname filesep '*.abf']);

    s = dir([dirname filesep  'subje*.txt']);

    subject = {};
    for i=1:numel(s)
        subject{i} = fileread([dirname filesep s(i).name]);
    end

    cols = {'channelName','probeName','probeRef','probeType','subject','firstAppears'};
    datatypes = {'string','string','double','string','string','string'};

    probetable = table('Size',[0 numel(cols)],'VariableNames',cols,'VariableTypes',datatypes);

    for i=1:numel(d)
        h = ndr.format.axon.read_abf_header([dirname filesep d(i).name]);
        [name,ref,daqsysstr,subjectlist] = ndi.setup.conv.marder.channelnames2daqsystemstrings(h.recChNames,'marder_abf',subject,...
            'forceIgnore2',options.forceIgnore2);
        for j=1:numel(name)
            if j<=numel(h.recChNames)
                if isempty(find(strcmp(h.recChNames{j},probetable.("channelName"))))
                    if any(lower(h.recChNames{j})=='a') & any(lower(h.recChNames{j})=='v')
                        probeType = 'sharp-Vm';
                        name{j} = 'XP';
                    elseif any(lower(h.recChNames{j})=='a') & any(lower(h.recChNames{j})=='i')
                        probeType = 'sharp-Im';
                        name{j} = 'XP';
                    elseif ~isempty(findstr(lower(h.recChNames{j}),'temp'))
                        probeType = 'thermometer';
                    else
                        probeType = 'n-trode';
                    end
                    probetable_new = cell2table({ h.recChNames{j} name{j} ref(j) probeType subjectlist{j} d(i).name},...
                        'VariableNames',cols);
                    probetable = cat(1,probetable,probetable_new);
                end
            else, probetable_new = cell2table({ 'nothing' name{j} ref(j) 'unknown' subjectlist{j} d(i).name},...
                        'VariableNames',cols);
            end
         end
    end

    writetable(probetable,[dirname filesep 'probeTable.csv']);
