function convertoldnsd2ndi(pathname)
    % NDI_CONVERTOLDNSD2NDI - convert an old 'nsd' session to 'ndi'
    %
    % ndi.fun.convertoldnsd2ndi(PATHNAME)
    %
    % Converts the NDS_SESSION_DIR session at PATHNAME to the new 'ndi' name
    % convention. Needs to be run on MacOS for the unix tools used (might work on Linux).
    %
    % The following irreversible changes are made:
    %
    % (1) Any instance of 'nsd' in a filename is changed to 'ndi'.
    % (2) Any instance of 'NSD' in a filename is changed to 'NDI'.
    % (3) All instances of 'nsd' in .m, .json, .txt *object_* files are replaced with 'ndi'.
    % (4) All instances of 'NSD' in .m, .json, .txt or *object_* files are replaced with 'NDI'.
    %
    % This function is depricated and should be irrelevant shortly as everyone uses 'NDI' instead of 'NSD'

    done = 0;

    while ~done,
        alldirs = split(genpath(pathname),pathsep);
        for i=1:numel(alldirs),
            newname = strrep(alldirs{i},'nsd','ndi');
            if ~strcmp(newname,alldirs{i}),
                movefile(alldirs{i},newname);
                break;
            end;
        end;
        if i==numel(alldirs),
            done = 1;
        end;
    end;

    str{1} = ['find ' pathname  ' -type f -name ''*nsd*'' -exec bash -c ''mv "$1" "${1/nsd/ndi}"'' -- {} \;'];
    str{end+1} = ['find ' pathname  ' -type f -name ''*NDI*'' -exec bash -c ''mv "$1" "${1/NSD/NDI}"'' -- {} \;'];

    str{end+1} = ['find ' pathname  ' -type f -name ''*.txt'' -exec sed -i '''' s/nsd/ndi/g {} +'];
    str{end+1} = ['find ' pathname  ' -type f -name ''*.m'' -exec sed -i '''' s/nsd/ndi/g {} +'];
    str{end+1} = ['find ' pathname  ' -type f -name ''*.json'' -exec sed -i '''' s/nsd/ndi/g {} +'];
    str{end+1} = ['find ' pathname  ' -type f -name ''*object_*'' -exec bash -c ''LC_ALL=C sed -i "" s:nsd:ndi:g "$1"'' -- {} \;'];
    str{end+1} = ['find ' pathname  ' -type f -name ''*.ndi''  -exec sed -i '''' s/nsd/ndi/g {} +'];

    str{end+1} = ['find ' pathname  ' -type f -name ''*.txt'' -exec sed -i '''' s/NSD/NDI/g {} +'];
    str{end+1} = ['find ' pathname  ' -type f -name ''*.m'' -exec sed -i '''' s/NSD/NDI/g {} +'];
    str{end+1} = ['find ' pathname  ' -type f -name ''*.json'' -exec sed -i '''' s/NSD/NDI/g {} +'];

    for i=1:numel(str),
        system(str{i});
    end;
