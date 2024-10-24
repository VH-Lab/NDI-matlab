function abfprobetable2epochprobemap(S)
    % Create epochprobemap files for a Marder ndi session
    %
    % ABFPROBETABLE2EPOCHPROBEMAP(S)
    %
    % Reads all ABF files in the NDI session S and creates corresponding
    % epochprobemap files using the 'probetable.csv' file in the main directory.
    %
    %

    arguments
        S (1,1)
    end

    dirname = S.getpath();

    probetable = readtable([dirname filesep 'probetable.csv'],'Delimiter',',');

    daqname = 'marder_abf';

    s = dir([dirname filesep  'subje*.txt']);

    subject = {};
    for i=1:numel(s),
        subject{i} = fileread([dirname filesep s(i).name]);
        mysub = S.database_search(ndi.query('subject.local_identifier','exact_string',subject{i}));
        if isempty(mysub),
            mysub = ndi.subject(subject{i},['Crab from Eve Marder Lab at Brandeis']);
            mysubdoc = mysub.newdocument + S.newdocument();
            S.database_add(mysubdoc);
        end;
    end;

    d = dir([dirname filesep '*.abf']);

    for i=1:numel(d),
        h = ndr.format.axon.read_abf_header([dirname filesep d(i).name]);
        for k=1:numel(s),
            probemap = ndi.epoch.epochprobemap_daqsystem('stimulation',k,'stimulator',...
                'marder_abf:ai1',subject{k});
        end;

        for j=1:numel(h.recChNames),
            [name,ref,probeType,subjectlist] = ndi.setup.conv.marder.channelnametable2probename(h.recChNames{j},probetable);
            daqsysstr = ndi.daq.daqsystemstring(daqname,{'ai'},j);
            probemap(end+1) = ndi.epoch.epochprobemap_daqsystem(name,ref,probeType,...
                daqsysstr.devicestring(),subjectlist);
        end;
        [myparent,myfile,myext] = fileparts([dirname filesep d(i).name]);
        probemap.savetofile([dirname filesep myfile '.epochprobemap.txt']);
    end;
