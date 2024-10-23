function [probename, proberef, subjectname] = channelname2probename(chName, subjects, options)
    % CHANNELNAME2PROBENAME - convert a Marder channel name to a probe name
    %
    % [PROBENAME, PROBEREF, SUBJECTNAME] = CHANNELNAME2PROBENAME(CHNAME, SUBJECTS)
    %
    % Given a channel name (e.g., 'DGN1_A','lvn','lvn2'), returns a probe name
    % and subject name. PROBEREF is always 1.
    %
    % If there is more than one subject (usually a maximum of 2), then the
    % program looks for a '1' or '2' in CHNAME. If none is found, then it is
    % assumed there is only 1 subject and 1 is the end of the string.
    % If a 2 is found and there is no second subject, a warning is produced.
    %

    arguments
        chName
        subjects
        options.forceIgnore2 = false;
    end

    probename = '';
    proberef = 1;

    % look for a 1 or a 2

    theintegers = cellfun(@str2num,regexp(chName,'\d+','match'));

    hasone = ismember(theintegers,1);
    hastwo = ismember(theintegers,2);
    if isempty(hasone),
        hasone = false;
    end;
    if isempty(hastwo),
        hastwo = false;
    end;

    if hasone&hastwo,
        error(['Do not know how to proceed with both 1 and 2 in string ' chName '.']);
    end;

    if ~hastwo | options.forceIgnore2,
        channel_str = '1';
        subjectname = subjects{1};
    elseif hastwo,
        channel_str = '2';
        subjectname = subjects{2};
    end;

    standard_strings = {'dgn','lgn','lvn','pdn','pyn','mvn','PhysiTemp'};

    for i=1:numel(standard_strings),
        if ~isempty(findstr(lower(chName),lower(standard_strings{i}))),
            probename = [standard_strings{i} '_' channel_str];
            break;
        end;
    end;

    if isempty(probename), % did not match standard_string,
        probename = matlab.lang.makeValidName(chName);
    end
