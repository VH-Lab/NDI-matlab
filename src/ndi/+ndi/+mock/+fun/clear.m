function clear(S)
    % CLEAR - clear mock documents from an ndi.session
    %
    % ndi.mock.fun.clear(S)
    %
    % Removes all mock database documents from an ndi.session.
    %
    % Removes all mock subjects, which should remove all mock probes
    % or elements based on those subjects and analyses of those probes.
    %

    arguments
        S (1,1) ndi.session
    end

    s = S.database_search(ndi.query('subject.local_identifier','contains_string','mock'));

    S.database_rm(s);
