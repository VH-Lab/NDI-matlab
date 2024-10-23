function id = empty_id()
    % EMPTY_ID - produce the empty session id
    %
    % ID = ndi.session.empty_id()
    %
    % Produce a string that indicates "no specific session"
    % or "applies in any session".
    %
    % The string is '0000000000000000_0000000000000000'
    %

    my_new_id = ndi.ido();

    id = my_new_id.unique_id();

    for i=1:numel(id),
        if (id(i)~='_'),
            id(i) = '0';
        end;
    end;


