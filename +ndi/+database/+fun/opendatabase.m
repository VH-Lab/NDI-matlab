function db = opendatabase(database_path, session_unique_reference)
    % OPENDATABASE - open the database associated with an session
    %
    % DB = ndi.database.fun.opendatabase(DATABASE_PATH, SESSION_UNIQUE_REFERENCE)
    %
    % Searches the file path DATABASE_PATH for any known databases
    % in NDI_DATABASEHIERACHY. If it finds a database of subtype ndi.database,
    % then it is opened and returned in DB.
    %
    % If it finds no databases, then it tries to create a new database following
    % the order in the hierarchy.
    %
    % Otherwise, DB is empty.
    %

    if nargin<2,
        session_unique_reference = '12345'; % this is not required for most database types
    end;

    db = [];

    databasehierarchy = ndi.common.getDatabaseHierarchy();

    for i=1:numel(databasehierarchy),
        d = dir([database_path filesep '*' databasehierarchy(i).extension]);
        if ~isempty(d), % found one
            if numel(d)>1,
                error(['Too many matching files.']);
            end;
            fname = [database_path filesep d(1).name];
            evalstr = strrep(databasehierarchy(i).code,'FILENAME',fname);
            evalstr = strrep(evalstr,'FILEPATH',[database_path filesep]);
            evalstr = strrep(evalstr,'SESSION_REFERENCE',session_unique_reference);
            eval(evalstr);
            break;
        end;
    end;

    if isempty(db),
        for i=1:numel(databasehierarchy),
            if ~isempty(databasehierarchy(i).newcode),
                evalstr = strrep(databasehierarchy(i).newcode,'FILEPATH',[database_path filesep]);
                evalstr = strrep(evalstr,'SESSION_REFERENCE',session_unique_reference);
                eval(evalstr);
            end;
            break;
        end
    end
