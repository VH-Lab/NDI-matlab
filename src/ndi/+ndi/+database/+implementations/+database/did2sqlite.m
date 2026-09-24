classdef did2sqlite < ndi.database
    % did2sqlite - an ndi.database backed by a did2 SQLite document store.
    %
    %   THE PROBLEM THIS EXISTS FOR
    %   ---------------------------
    %   `ndi.migrate.local` writes its output with `did2.database.sqlitedb`.
    %   `ndi.session.dir` opens a database with
    %   `ndi.database.implementations.database.didsqlite`, which wraps the
    %   LEGACY `did.implementations.sqlitedb`. Those are two different
    %   on-disk formats, not two names for one thing, so opening a migrated
    %   session through NDI failed before it read a single document:
    %
    %       Error ID: 'DID:SQLITEDB:OPEN'
    %         Error opening .../did-sqlite.sqlite as a DID SQLite database:
    %         "branches" table not found in database
    %         did.implementations.sqlitedb/open_db (line 832)
    %         <- ndi.database.implementations.database.didsqlite (line 25)
    %         <- ndi.database.fun.opendatabase (line 44)
    %         <- ndi.session.dir (line 101)
    %
    %   The legacy backend is BRANCH-VERSIONED (tables `branches`,
    %   `docs`, ...); the did2 backend is a flat document store (tables
    %   `documents`, `superclasses`, `depends_on`, `queryable_array_elem`,
    %   `meta`) and contains no notion of a branch anywhere. So the fix is
    %   not a missing table in the migrator's output -- it is this class:
    %   an ndi.database that speaks did2.
    %
    %   WHAT IS AND IS NOT IMPLEMENTED
    %   ------------------------------
    %   Document add / read / remove / search / alldocids are implemented by
    %   delegating to did2.database.sqlitedb.
    %
    %   BINARY (file) documents are NOT, and they error rather than
    %   returning something. `did2.database.sqlitedb` has no file store at
    %   all -- it persists the document body and the two query sidecars and
    %   nothing else -- so there is no path from a document id and a
    %   filename to bytes to hand back. Returning empty here would make a
    %   dataset with attached files read as a dataset with none, which is
    %   the hollow-document failure this project has paid for repeatedly.
    %   An error names the gap instead.
    %
    %   See also: ndi.database, did2.database.sqlitedb,
    %             ndi.database.implementations.database.didsqlite,
    %             ndi.database.fun.databasehierarchyinit.

    properties
        db        % did2.database.sqlitedb
    end

    properties (SetAccess = protected, GetAccess = public)
        database_filename (1,:) char = ''   % the file this object opened
    end

    methods

        function obj = did2sqlite(varargin)
            % did2sqlite - make a new ndi.database.implementations.database.did2sqlite
            %
            % OBJ = ndi.database.implementations.database.did2sqlite(...
            %     PATH, SESSION_UNIQUE_REFERENCE, COMMAND, FILENAME)
            %
            % COMMAND is 'load' or 'new'. FILENAME, when given, is the full
            % path of the did2 sqlite file; when omitted the default name
            % (see DEFAULTFILENAME) inside PATH is used.
            %
            % UNLIKE `didsqlite`, THE FILENAME IS NOT HARD-CODED. didsqlite
            % ignores the FILENAME it is handed and always opens
            % `did-sqlite.sqlite`, which is why a migrated database could
            % not be opened even once this class existed: nothing was able
            % to tell NDI which file to open. `ndi.database.fun.opendatabase`
            % passes the file it matched, and this constructor uses it.
            obj = obj@ndi.database(varargin{:});

            fname = '';
            if numel(varargin) > 3
                fname = char(varargin{4});
            end
            if isempty(fname)
                fname = fullfile(obj.path, ...
                    ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME());
            end
            obj.database_filename = fname;

            obj.db = did2.database.sqlitedb(fname);

            if ~isfolder(obj.file_directory())
                mkdir(obj.file_directory());
            end
        end % did2sqlite()

    end

    methods % public

        function docids = alldocids(obj)
            % ALLDOCIDS - return all document ids in the database
            %
            % DOCIDS = ALLDOCIDS(OBJ)
            %
            % Returns a cell array of strings. Empty if there are no
            % documents.
            docids = obj.db.allIds();
        end % alldocids()

    end

    methods (Static)

        function name = DEFAULTFILENAME()
            % DEFAULTFILENAME - the did2 database file name inside a session's .ndi directory
            %
            % `ndi.migrate.local` names its output
            % `fullfile(ndiDir, [options.TargetVersion '.sqlite'])`, so the
            % file this has to match is `<TargetVersion>.sqlite`.
            %
            % IT IS PINNED TO V_eta AND NOT TO THAT OPTION'S DEFAULT, WHICH
            % IS STILL 'V_delta' (`local.m`, `options.TargetVersion (1,:)
            % char = 'V_delta'`). Two reasons, and the second is the one
            % that matters:
            %
            %   * V_alpha..V_zeta were BRAINSTORM iterations. None was ever
            %     used for real data. V_eta is the first successor intended
            %     to hold anything, so it is the only version a database on
            %     disk should be found under.
            %   * The search cannot be widened to any `*.sqlite`:
            %     `opendatabase` globs `['*' extension]` and ERRORS on more
            %     than one match, and every session already contains
            %     `did-sqlite.sqlite`. A wildcard would turn "open a
            %     migrated session" into "too many matching files" for
            %     every session in existence.
            %
            % Stated ONCE, here, so "what file does NDI look for" is
            % greppable rather than spread across a hierarchy entry and a
            % constructor default.
            name = 'V_eta.sqlite';
        end % DEFAULTFILENAME()

        function q2 = toDid2Query(q)
            % TODID2QUERY - convert an ndi.query / did.query to a did2.query
            %
            % Q2 = TODID2QUERY(Q)
            %
            % BOTH query classes carry a `searchstructure` struct array with
            % the SAME four fields -- field, operation, param1, param2 --
            % so the conversion is structural rather than a re-implementation
            % of the query language. Two implementations of "what does this
            % query mean" that disagree is worse than one that is missing.
            %
            % EACH TERM IS REBUILT THROUGH `did2.query.searchstruct` RATHER
            % THAN COPIED ACROSS, and the reason is validation, not
            % tidiness. `did2.query`'s struct-array constructor branch runs
            % only `validateSearchstructFields`, which checks that the four
            % FIELD NAMES are present and says nothing about the operator;
            % `mustBeKnownOp` is applied by `searchstruct`'s own arguments
            % block and is private, so it cannot be called from here.
            % Handing the terms back through `searchstruct` therefore reuses
            % did2's operator list instead of this file keeping a second
            % copy of it -- an operator did2 does not implement is refused
            % at conversion, naming itself, instead of surviving into a
            % search that quietly matches nothing.
            if isa(q, 'did2.query')
                q2 = q;
                return;
            end
            if ~isa(q, 'did.query')
                error('NDI:did2sqlite:badQuery', ...
                    ['ndi.database.implementations.database.did2sqlite ' ...
                     'needs an ndi.query, did.query or did2.query (got "%s").'], ...
                    class(q));
            end

            ss = [];
            for i = 1:numel(q)
                sHere = q(i).searchstructure;
                for j = 1:numel(sHere)
                    try
                        term = did2.query.searchstruct(sHere(j).field, ...
                            sHere(j).operation, sHere(j).param1, sHere(j).param2);
                    catch ME
                        error('NDI:did2sqlite:unsupportedOperation', ...
                            ['This database is backed by did2, which will ' ...
                             'not accept the query term operation="%s" on ' ...
                             'field "%s" (%s). The query is refused rather ' ...
                             'than run with that term dropped.'], ...
                            char(sHere(j).operation), char(sHere(j).field), ...
                            ME.message);
                    end
                    ss = [ss; term]; %#ok<AGROW>
                end
            end
            if isempty(ss)
                q2 = did2.query.all();
                return;
            end
            q2 = did2.query(ss);
        end % toDid2Query()

    end

    methods (Access=protected)

        function [hCleanup, filename] = do_open_database(obj)
            % DO_OPEN_DATABASE - report the open connection
            %
            % `did2.database.sqlitedb` opens in its constructor and stays
            % open for the object's lifetime; it has no open() that hands
            % back a cleanup handle the way the legacy backend does. So
            % there is nothing for the caller to release, and hCleanup is
            % empty ON PURPOSE rather than by omission.
            hCleanup = [];
            filename = obj.database_filename;
        end

        function obj = do_add(obj, ndi_document_obj, add_parameters) %#ok<INUSD>
            docs = ndi.database.implementations.database.did2sqlite.toDid2Documents( ...
                ndi_document_obj);
            obj.db.add(docs);
        end % do_add

        function [ndi_document_obj] = do_read(obj, ndi_document_id)
            raw = obj.db.get(ndi_document_id);
            % Route the stored body through the same read normaliser every
            % other backend uses, so callers above the ndi.database
            % abstraction only ever see ndi.document objects. It already
            % accepts a did2.document (its own docstring says so), and a
            % V_eta body now ranks BEYOND the read target, so it passes
            % through untouched rather than being pushed back through
            % migrators aimed at a version it has already passed.
            if iscell(raw)
                ndi_document_obj = cell(size(raw));
                for i = 1:numel(raw)
                    ndi_document_obj{i} = ...
                        ndi.database.internal.applyReadNormalization(raw{i});
                end
            else
                ndi_document_obj = ...
                    ndi.database.internal.applyReadNormalization(raw);
            end
        end % do_read

        function obj = do_remove(obj, ndi_document_id)
            obj.db.remove(ndi_document_id);
        end % do_remove

        function [ndi_document_objs] = do_search(obj, searchoptions, searchparams) %#ok<INUSL>
            q2 = ndi.database.implementations.database.did2sqlite.toDid2Query( ...
                searchparams);
            doc_ids = obj.db.searchIds(q2);
            ndi_document_objs = {};
            for i = 1:numel(doc_ids)
                ndi_document_objs{i} = obj.do_read(doc_ids{i}); %#ok<AGROW>
            end
        end % do_search()

        function [ndi_binarydoc_obj] = do_openbinarydoc(obj, ndi_document_id, filename) %#ok<STOUT,INUSD>
            error('NDI:did2sqlite:noBinaryStore', ...
                ['This database is backed by did2.database.sqlitedb, which ' ...
                 'stores document bodies and the query sidecars and has NO ' ...
                 'file store, so there is no way to produce the bytes of ' ...
                 '"%s" on document %s. This errors rather than returning ' ...
                 'empty: a dataset with attached files must not read as a ' ...
                 'dataset with none.'], filename, ndi_document_id);
        end % do_openbinarydoc()

        function [tf, file_path] = check_exist_binarydoc(obj, ndi_document_id, filename) %#ok<INUSD>
            % A did2 database has no file store, so the honest answer is
            % "no" with no path -- and unlike do_openbinarydoc this one is
            % ASKED speculatively by callers deciding whether to read, so a
            % false is a real answer rather than a swallowed failure.
            tf = false;
            file_path = '';
        end % check_exist_binarydoc()

        function [ndi_binarydoc_matfid_obj] = do_closebinarydoc(obj, ndi_binarydoc_matfid_obj) %#ok<INUSL>
            % Nothing can have been opened (do_openbinarydoc always
            % errors), so there is nothing to close.
        end % do_closebinarydoc()

        function [file_dir] = file_directory(obj)
            % FILE_DIRECTORY - where ingested files would live
            %
            % Same layout as the legacy backend so a session migrated in
            % place keeps its existing `files/` directory rather than
            % growing a second one. Nothing in this class reads or writes
            % it yet -- see do_openbinarydoc.
            file_dir = fullfile(obj.path, 'files');
        end % file_directory

    end

    methods (Static, Access = private)

        function docs = toDid2Documents(ndi_document_obj)
            % TODID2DOCUMENTS - ndi.document (or a cell array of them) -> did2.document
            if ~iscell(ndi_document_obj)
                ndi_document_obj = {ndi_document_obj};
            end
            docs = cell(size(ndi_document_obj));
            for i = 1:numel(ndi_document_obj)
                d = ndi_document_obj{i};
                if isa(d, 'did2.document')
                    docs{i} = d;
                elseif isa(d, 'ndi.document') || isa(d, 'did.document')
                    docs{i} = did2.document(d.document_properties);
                elseif isstruct(d)
                    docs{i} = did2.document(d);
                else
                    error('NDI:did2sqlite:badDocument', ...
                        ['Cannot add an object of class "%s" to a did2 ' ...
                         'database.'], class(d));
                end
            end
        end % toDid2Documents()

    end

end
