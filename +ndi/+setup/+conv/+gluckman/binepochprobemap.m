function binepochprobemap(S, options)
    % BINEPOCHPROBEMAP - Create epochprobemap files for a Gluckman BIN directory
    %
    % BINEPOCHPROBEMAP(DIRNAME)
    %
    % Reads all BIN files in DIRNAME and creates corresponding epochprobemap files.
    %
    %

    arguments
        S (1,1)
        options.nothing = 0
    end

    dirname = S.getpath();

    d = dir([dirname filesep '*.bin']);

    s = dir([dirname filesep  'subje*.txt']);

    subject = {};
    for i=1:numel(s),
        subject{i} = fileread([dirname filesep s(i).name]);
        mysub = S.database_search(ndi.query('subject.local_identifier','exact_string',subject{i}));
        if isempty(mysub),
            mysub = ndi.subject(subject{i},['Gluckman Lab at Penn State']);
            mysubdoc = mysub.newdocument + S.newdocument();
            S.database_add(mysubdoc);
        end;
    end;

    for i=1:numel(d),
        h = ndr.format.bjg.read_bjg_header([dirname filesep d(i).name]);
        [name,ref,daqsysstr,subjectlist,probetype] = ...
            ndi.setup.conv.gluckman.channelnames2daqsystemstrings(h.channel_names,'gluckman_bjgbin',subject);
        for j=1:numel(name),
            if j==1,
                probemap = ndi.epoch.epochprobemap_daqsystem(name{j},ref(j),probetype{j},daqsysstr(j).devicestring(),subjectlist{j});
            else,
                probemap(end+1) = ndi.epoch.epochprobemap_daqsystem(name{j},ref(j),probetype{j},daqsysstr(j).devicestring(),subjectlist{j});
            end;
        end;
        [myparent,myfile,myext] = fileparts([dirname filesep d(i).name]);
        probemap.savetofile([dirname filesep myfile '.epochprobemap.txt']);
    end;
