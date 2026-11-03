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
    % So ORDER CARRIES TWO MEANINGS: search precedence, and which backend a
    % brand-new session gets.
    %
    % ON THE V2 LINE (Decided by Jess Haley, 2026-11-03 [V2 branch writes V2
    % only] and [v1 database read-only on the v2 line], did-schema
    % did_v2_go_forward_class_audit.md: "We're on the v2 branch. That should
    % write v2 exclusively and read v1 and v2."):
    %
    %   1. did2sqlite, did_v2.sqlite -- opens a V2 database, and is the entry
    %      that CREATES the database of a new session: a new session gets a
    %      V2 (did2) database.
    %   2. did2sqlite, V_eta.sqlite -- the same store under the file name it
    %      had before 2026-11-01 ([V2 database file renamed]); opened, never
    %      created.
    %   3. didsqlite, did-sqlite.sqlite -- an existing v1 database. It is
    %      opened READ-ONLY: reading works, and any write is refused with an
    %      error naming ndi.migrate.local (see
    %      ndi.database.implementations.database.didsqlite). It comes after
    %      the V2 entries because a session migrated in place keeps its
    %      did-sqlite.sqlite beside the did_v2.sqlite ndi.migrate.local
    %      writes, and the migrated database is the one to open.
    %
    % `didsqlite` hard-codes `did-sqlite.sqlite` in its own constructor, so
    % entry 3's extension IS that file name: the search finds an existing v1
    % database by the file that holds it, and nothing creates one.
    %
    % See also: ndi.database.fun.opendatabase,
    %           ndi.database.implementations.database.didsqlite,
    %           ndi.database.implementations.database.did2sqlite

    % Entry 1 -- the did2 document store. Opens did_v2.sqlite and creates
    % it for a new session.
    databasehierarchy = struct( ...
        'extension',    ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME(), ...
        'code',         'db=ndi.database.implementations.database.did2sqlite(''FILEPATH'', ''SESSION_REFERENCE'', ''load'',''FILENAME'');',  ...
        'newcode',      ['db=ndi.database.implementations.database.did2sqlite(''FILEPATH'', ''SESSION_REFERENCE'', ''new'',''FILEPATH' ...
                         ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME() ''');'] ...
        );

    % Entry 2 -- the same did2 store under the file name it had before
    % 2026-11-01 ([V2 database file renamed], Decided by Jess Haley,
    % 2026-11-01): NDI still opens an existing V_eta.sqlite. After entry 1,
    % so a folder holding did_v2.sqlite opens that one.
    databasehierarchy(2) = struct( ...
        'extension',    ndi.database.implementations.database.did2sqlite.LEGACYFILENAME(), ...
        'code',         'db=ndi.database.implementations.database.did2sqlite(''FILEPATH'', ''SESSION_REFERENCE'', ''load'',''FILENAME'');',  ...
        'newcode',      '' ...
        );

    % Entry 3 -- an existing v1 (legacy did, branch-versioned) database,
    % opened read-only ([v1 database read-only on the v2 line]). Never
    % created on the V2 line.
    databasehierarchy(3) = struct( ...
        'extension',    ndi.database.implementations.database.didsqlite.FILENAME(), ...
        'code',         'db=ndi.database.implementations.database.didsqlite(''FILEPATH'', ''SESSION_REFERENCE'', ''load'',''FILENAME'');',  ...
        'newcode',      '' ...
        );
