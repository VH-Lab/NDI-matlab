function [probename, proberef, probetype, subjectname] = channelnametable2probename(chName, probetable, options)
    % CHANNELNAME2PROBE - convert a Marder channel name to a probe name
    %
    % [PROBENAME, PROBEREF, PROBETYPE, SUBJECTNAME] = CHANNELNAME2PROBENAME(CHNAME, PROBETABLE)
    %
    % Given a channel name (e.g., 'DGN1_A','lvn','lvn2'), returns a probe name
    % and subject name. PROBEREF is always 1.
    %
    % The probe information is assigned according to information in PROBETABLE, a table
    % with columns "channelName", "probeName", "probeRef", "probeType", "subjectName".
    %
    %

    arguments
        chName
        probetable
        options.nothing = 0
    end



    i = find(strcmp(chName,probetable.("channelName")));

    if isempty(i),
        error(['No match found.']);
    end;

    probename = probetable{i,"probeName"}{1};
    proberef = probetable{i,"probeRef"};
    probetype = probetable{i,"probeType"}{1};
    subjectname = probetable{i,"subject"}{1};


