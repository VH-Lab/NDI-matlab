function smrepochprobemap(S, options)
    % Create epochprobemap files for a Marder SMR directory
    %
    % SMREPOCHPROBEMAP(DIRNAME)
    %
    % Reads all SMR files in DIRNAME and creates corresponding epochprobemap files.
    %
    %

    arguments
        S (1,1)
        options.forceIgnore2 = false
    end

    dirname = S.getpath();

    d = dir([dirname filesep '*.smr']);

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

    for i=1:numel(d),
        h = ndr.format.ced.read_SOMSMR_header([dirname filesep d(i).name]);
        inc = find([h.channelinfo.kind]==1);
        [name,ref,daqsysstr,subjectlist] = ndi.setup.conv.marder.channelnames2daqsystemstrings({h.channelinfo(inc).title},'marder_ced',subject,...
            'forceIgnore2',options.forceIgnore2,'channelnumbers',[h.channelinfo(inc).number]);
        for j=1:numel(name),
            if j==1,
                probemap = ndi.epoch.epochprobemap_daqsystem(name{j},ref(j),'n-trode',daqsysstr(j).devicestring(),subjectlist{j});
            else,
                probemap(end+1) = ndi.epoch.epochprobemap_daqsystem(name{j},ref(j),'n-trode',daqsysstr(j).devicestring(),subjectlist{j});
            end;
        end;
        [myparent,myfile,myext] = fileparts([dirname filesep d(i).name]);
        probemap.savetofile([dirname filesep myfile '.epochprobemap.txt']);
    end;
