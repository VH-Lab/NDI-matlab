function abfprobetable2probemap(S,options)
% ABFPROBETABLE2PROBEMAP - Create epochprobemap files for a Marder ndi session
%
%   ABFPROBETABLE2PROBEMAP(S) Reads all ABF files in the NDI session S and 
%   creates corresponding epochprobemap files using the 'probetable.csv' 
%   and 'subject*.txt' files in the main directory.
%
    
    arguments
        S (1,1) {mustBeA(S, ["ndi.session", "ndi.dataset"])}
        options.acquisitionDelay (1,1) duration = seconds(0)
        options.overwrite (1,1) logical = false
    end

    dirname = S.getpath();

    probetable = readtable([dirname filesep 'probetable.csv'],'Delimiter',',');

    daqname = 'marder_abf';

    % Add subjects to database (if not already added)
    s = dir([dirname filesep  'subje*.txt']);
    subject = {};
    for i=1:numel(s)
        subject{i} = fileread([dirname filesep s(i).name]);
        mysub = S.database_search(ndi.query('subject.local_identifier','exact_string',subject{i}));
        if options.overwrite
            S.database_rm(mysub);
            mysub = [];
        end
        if isempty(mysub) 
            mysub = ndi.subject(subject{i},['Crab from Eve Marder Lab at Brandeis']);
            mysubdoc = mysub.newdocument + S.newdocument();
            S.database_add(mysubdoc);
        end
    end

    % Find abf files that do not yet have accompanying epochprobemaps
    d = dir([dirname filesep '*.abf']);
    if options.overwrite
        epoch_i = 1:numel(d);
    else
        epm = dir([dirname filesep '*.epochprobemap.txt']);
        epm_fileNames = {epm(:).name};
        fileNames = extractBefore(epm_fileNames,'.');
        missing = ~contains({d(:).name},fileNames);

        % Skip files that do not meet criteria
        timeDelay = datetime('now') - datetime([d(:).datenum],'ConvertFrom','datenum');
        skip = timeDelay < options.acquisitionDelay;

        epoch_i = find(missing & ~skip);
    end

    % Create epochprobemaps
    for i = epoch_i
        h = ndr.format.axon.read_abf_header([dirname filesep d(i).name]);
        for k=1:numel(s)
            probemap = ndi.epoch.epochprobemap_daqsystem('stimulation',k,'stimulator',...
                'marder_abf:ai1',subject{k});
        end

        for j=1:numel(h.recChNames)
            [name,ref,probeType,subjectlist] = ...
                ndi.setup.conv.marder.channelnametable2probename(h.recChNames{j},probetable);
            daqsysstr = ndi.daq.daqsystemstring(daqname,{'ai'},j);
            for z=1:numel(name)
                probemap(end+1) = ndi.epoch.epochprobemap_daqsystem(name{z},ref(z),probeType{z},...
                    daqsysstr.devicestring(),subjectlist{z});
            end
        end
        [myparent,myfile,myext] = fileparts([dirname filesep d(i).name]);
        probemap.savetofile([dirname filesep myfile '.epochprobemap.txt']);
    end
