function fix_empty_records(dirname, N)
    % FIX_EMPTY_RECORDS
    %
    % FIX_EMPTY_RECORDS(DIRNAME, N)
    %
    % Neuter reference.txt files in directories that have fewer than N files.
    %

    ds = dirstruct(dirname);

    T = getalltests(ds);

    for t=1:numel(T),

    end;
