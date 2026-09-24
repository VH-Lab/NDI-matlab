function databasehierarchy = databasehierarchyinit()
    % DATABASEHIERARCHYINIT - Initializes the list of databases to try
    %
    % ndi.database.fun.databasehierarchyinit
    %
    % Returns a struct array, one entry per database backend NDI knows how
    % to open. `ndi.database.fun.opendatabase` walks it in order:
    %
    %   * FIRST it looks for an existing file matching each entry's
    %     `extension`, in order, and evaluates that entry's `code`.
    %   * If nothing matched, it evaluates the FIRST entry's `newcode` to
    %     create a database. (The creation loop breaks unconditionally
    %     after the first iteration, so entry 1 is the only entry that can
    %     ever create one.)
    %
    % So ORDER CARRIES TWO DIFFERENT MEANINGS: search precedence, and which
    % backend a brand-new session gets. `didsqlite` is entry 1 because it
    % is the backend NDI creates today, and that is deliberately unchanged
    % here -- adding a way to OPEN a migrated database must not silently
    % change what a NEW session is written with.
    %
    % TWO FACTS ABOUT THIS FUNCTION THAT ARE EASY TO MIS-READ
    % -------------------------------------------------------
    % (1) It used to ASSIGN `databasehierarchy` TWICE, with the second
    %     assignment overwriting the first rather than appending to it. The
    %     `matlabdumbjsondb2` entry was therefore DEAD -- it could never be
    %     reached, whatever was on disk. It is left out rather than
    %     resurrected: bringing it back would change which backend opens an
    %     existing session, which is a separate decision from this one.
    %
    % (2) `didsqlite`'s `extension` is 'ndi.dumbjsondb.json' and its
    %     filename arguments are ignored -- the class hard-codes
    %     `did-sqlite.sqlite` in its own constructor. So for a normal
    %     session the search loop matches NOTHING and the database is
    %     opened by the CREATION branch, which then finds the existing
    %     file. The extension matching has been vestigial for that backend.
    %     `did2sqlite` does not work this way: it opens the file it is
    %     handed, which is what makes a migrated database findable.
    %
    % See also: ndi.database.fun.opendatabase,
    %           ndi.database.implementations.database.didsqlite,
    %           ndi.database.implementations.database.did2sqlite

    % Entry 1 -- the LEGACY did backend, branch-versioned. Creates new
    % databases (see the note above about the creation loop).
    databasehierarchy = struct( ...
        'extension',    'ndi.dumbjsondb.json', ...
        'code',         'db=ndi.database.implementations.database.didsqlite(''FILEPATH'', ''SESSION_REFERENCE'', ''load'',''FILENAME'');',  ...
        'newcode',      'db=ndi.database.implementations.database.didsqlite(''FILEPATH'', ''SESSION_REFERENCE'', ''new'',''FILEPATHndi.dumbjsondb.json'');' ...
        );

    % Entry 2 -- the did2 document store, which is what `ndi.migrate.local`
    % writes. `newcode` is EMPTY on purpose: this entry exists to OPEN a
    % migrated database, not to decide that new sessions become did2. That
    % is a product decision nobody has made, and an empty newcode makes the
    % absence explicit rather than leaving it to loop mechanics.
    databasehierarchy(2) = struct( ...
        'extension',    ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME(), ...
        'code',         'db=ndi.database.implementations.database.did2sqlite(''FILEPATH'', ''SESSION_REFERENCE'', ''load'',''FILENAME'');',  ...
        'newcode',      '' ...
        );
