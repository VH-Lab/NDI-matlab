% NDI_SESSION_DIR - NDI_SESSION_DIR object class - an session with an associated file directory
%

classdef dir < ndi.session
    properties (GetAccess=public,SetAccess=protected)
        path    % the file path of the session
    end

    methods
        function ndi_session_dir_obj = dir(reference, path, session_id)
        % ndi.session.dir - Create or open an ndi.session.dir object
        %
        % An ndi.session.dir is an ndi.session bound to a directory on disk.
        % The constructor supports three calling forms.
        %
        % --- One-input form ---
        %
        %   E = ndi.session.dir(PATHNAME)
        %
        % Open an existing session that is already stored at PATHNAME. The
        % session's REFERENCE and identifier are read from the database (or
        % from the .ndi/reference.txt and .ndi/unique_reference.txt files if
        % no database entry exists). It is an error to call this form on a
        % directory that does not already contain a session.
        %
        % --- Two-input form ---
        %
        %   E = ndi.session.dir(REFERENCE, PATHNAME)
        %
        % Create a new ndi.session.dir at PATHNAME, or open an existing one
        % there. REFERENCE is a human-readable label for the session.
        %
        % If PATHNAME does not yet contain a session, a new session is
        % created: a fresh identifier is generated, REFERENCE is recorded, an
        % .ndi subdirectory and database are initialized, and a session
        % document is added to the database.
        %
        % If PATHNAME already contains one or more sessions, the constructor
        % searches the database for session documents and selects the oldest
        % (the one with the earliest base.datestamp). The returned object's
        % identifier and reference are taken from that document, and the
        % REFERENCE argument supplied by the caller is effectively ignored.
        % Because selection is driven by what the database returns first,
        % this form is not suitable when more than one session lives at the
        % same path and you need a specific one; use the three-input form
        % below instead.
        %
        % --- Three-input form ---
        %
        %   E = ndi.session.dir(REFERENCE, PATHNAME, SESSION_ID)
        %
        % Open the session whose identifier is SESSION_ID at PATHNAME, and
        % bind it to REFERENCE. This form skips the database lookup that the
        % two-input form uses to pick a session, so it pins resolution to
        % exactly the session you name.
        %
        % Use this form when a dataset and a session share a directory (for
        % example, an ndi.dataset.dir whose default session sits at the
        % dataset root): the two-input form resolves to whichever session
        % the directory's stored metadata names first, which may not be the
        % session the caller intended.
        %
        % See also: ndi.session, ndi.session.dir/GETPATH

            if nargin<2
                if nargin >= 1
                    path = reference;
                end
                reference = 'temp';
            end

            ndi_session_dir_obj = ndi_session_dir_obj@ndi.session(reference);

            if nargin < 1 || isempty(path); return; end

            if ~isfolder(path)
                error(['Directory ' path ' does not exist.']);
            end

            ndi_session_dir_obj.path = char(path); % Ensure type is character vector

            should_we_try_to_read_from_database = 1;

            if nargin>2 % we have the session_id
                ndi_session_dir_obj.identifier = session_id;
                ndi_session_dir_obj.reference = reference;
                should_we_try_to_read_from_database = 0;
            else
                % next, figure out the ID; we won't use the one on disk unless we don't have a database entry

                d = dir([ndi_session_dir_obj.ndipathname() filesep 'unique_reference.txt']);
                if ~isempty(d)
                    ndi_session_dir_obj.identifier = strtrim(vlt.file.textfile2char(...
                        [ndi_session_dir_obj.ndipathname() filesep 'unique_reference.txt']));
                else
                    % make a provisional new one
                    ndi_session_dir_obj.identifier = ndi.ido.unique_id();
                end
            end

            % (a local first: `database` is not readable from this subclass,
            % only settable; ndi.session limits its GetAccess)
            db = ndi.database.fun.opendatabase(...
                ndi_session_dir_obj.ndipathname(), ndi_session_dir_obj.id());
            ndi_session_dir_obj.database = db;

            % Warn once if what was opened still holds v1 documents (Decided
            % by Jess Haley, 2026-10-23 [warn on v1 open]). Counted before
            % this constructor writes anything, so creating a new session
            % does not warn about the session document it is about to add.
            % ndi.dataset.dir silences this for the session opens it makes
            % and warns once for the dataset.
            ndi.database.fun.warnIfV1Documents(db, 'session', ndi_session_dir_obj.path);

            read_from_database = 0;

            if should_we_try_to_read_from_database
                % the session's own record: the session (or dataset) entity
                % whose base.id IS the session id, where session_id is an edge
                % (did-schema V_eta_relation_inheritance_plan.md, 2026-10-20);
                % otherwise its `session` documents (v1, and v2 on did-schema
                % main), scoped to the session id like every search here
                session_doc = ndi.v2.sessionRecord(ndi_session_dir_obj, ...
                    ndi_session_dir_obj.id());
                if ~isempty(session_doc)
                    % use the oldest
                    time_diff_max = 0;
                    time_loc = 0;
                    now_time = datetime('now','TimeZone','UTCLeapSeconds');
                    for i=1:numel(session_doc)
                        % BOTH VINTAGES. V_eta renamed base.datestamp ->
                        % base.creation_timestamp (did-schema, signed
                        % 2026-08-13). This loop reads a document straight out
                        % of the database, which may be pre- or post-migration,
                        % so it must accept either spelling. Reading only the v1
                        % name against a migrated database throws a missing-field
                        % error here rather than degrading quietly.
                        base_here = session_doc{i}.document_properties.base;
                        if isfield(base_here,'creation_timestamp')
                            stamp_here = base_here.creation_timestamp;
                        else
                            stamp_here = base_here.datestamp;
                        end
                        time_here = datetime(stamp_here,'TimeZone','UTCLeapSeconds');
                        time_diff_here = seconds(now_time-time_here);
                        if time_diff_here>time_diff_max
                            time_diff_max = time_diff_here;
                            time_loc = i;
                        end
                    end
                    session_doc = session_doc{time_loc};

                    ndi_session_dir_obj.identifier = session_doc.session_id();
                    % BOTH VINTAGES. V_eta renamed session.reference ->
                    % session.local_identifier -- the name `subject` and `epoch`
                    % already use for the same fact (did-schema, signed
                    % 2026-08-13). The OBJECT property stays `reference`: that is
                    % ndi.session's own public API, read at 20 call sites, and it
                    % is not what the migration renamed.
                    % and since 2026-10-08 the session may be an `entity` of type
                    % session, whose block is `entity` (ndi.v2.kindOf)
                    [record_kind, session_blk_name] = ndi.v2.kindOf(session_doc.document_properties);
                    session_blk = session_doc.document_properties.(session_blk_name);
                    reference_file = fullfile(ndi_session_dir_obj.ndipathname(), 'reference.txt');
                    if strcmp(record_kind, 'dataset') && isfile(reference_file)
                        % a dataset entity standing as the folder's own record:
                        % the folder's reference is its reference.txt, never
                        % the entity's local_identifier, which is the
                        % dataset's own (Haley decision #115)
                        ndi_session_dir_obj.reference = strtrim(vlt.file.textfile2char(reference_file));
                    elseif isfield(session_blk,'local_identifier') && ~isempty(session_blk.local_identifier)
                        ndi_session_dir_obj.reference = session_blk.local_identifier;
                    elseif isfield(session_blk,'reference')
                        ndi_session_dir_obj.reference = session_blk.reference;
                    elseif isfile(fullfile(ndi_session_dir_obj.ndipathname(), 'reference.txt'))
                        % a dataset entity standing as the dataset's own record
                        % has no local_identifier (ndi.setup.V2.createDataset)
                        ndi_session_dir_obj.reference = strtrim(vlt.file.textfile2char( ...
                            fullfile(ndi_session_dir_obj.ndipathname(), 'reference.txt')));
                    else
                        ndi_session_dir_obj.reference = char(ndi.v2.blockOf( ...
                            session_doc.document_properties, 'dataset', 'name', ''));
                    end
                    read_from_database = 1;
                end
            end

            if should_we_try_to_read_from_database & ~read_from_database
                d = dir([ndi_session_dir_obj.ndipathname() filesep 'reference.txt']);
                if ~isempty(d)
                    ndi_session_dir_obj.reference = strtrim(vlt.file.textfile2char(...
                        [ndi_session_dir_obj.ndipathname() filesep 'reference.txt']));
                elseif nargin==1
                    error(['Could not load the REFERENCE field from the database or path ' ndi_session_dir_obj.ndipathname() '.']);
                end
                % now we have both reference and id from either the files or the database, add it to db
                if isa(db, 'ndi.database.implementations.database.did2sqlite')
                    % A v2 (did2) database gets the v2 session record: an
                    % `entity` of type session whose id IS the session id,
                    % as ndi.setup.V2.createSession writes it, not a v1
                    % `session` document stamped did_v1. Decided by Jess
                    % Haley, 2026-10-29 [v1 writes into a V2 session]
                    % (did-schema did_v2_go_forward_class_audit.md): "the end
                    % state is that every NDI writer writes V2 documents".
                    % A v1 database keeps the v1 document below.
                    sid = ndi_session_dir_obj.id();
                    if ndi.session.dir.markedDataset(ndi_session_dir_obj.ndipathname())
                        % A dataset folder (ndi.dataset.dir marks it before
                        % it opens the folder): its own record is the
                        % `dataset` entity whose id is the session id, and
                        % no separate session record is written beside it;
                        % its reference stays in reference.txt and is not
                        % written into the entity (TEAM-SIGN-OFF [relation
                        % inheritance], Jess Haley 2026-10-21, did-schema
                        % did_v2_relation_inheritance_plan.md: "a dataset
                        % folder's own record is the dataset entity and its
                        % reference stays in reference.txt"). It is the bare
                        % dataset entity DID-matlab's migration writes for a
                        % dataset with no metadata (+migrators_j/private/
                        % jBareDataset.m): no name, no local_identifier.
                        recordKind = 'dataset';
                        recordFields = struct();
                    else
                        recordKind = 'session';
                        recordFields = struct('local_identifier', ndi_session_dir_obj.reference);
                    end
                    g = ndi.setup.V2.entityDocuments(recordKind, recordFields, ...
                        struct(), 'SessionId', sid, 'Id', sid);
                    ndi_session_dir_obj.database_add(cellfun(@(x) ndi.document(x), ...
                        g, 'UniformOutput', false));
                else
                    g = ndi.document('session','session.reference',ndi_session_dir_obj.reference) + ...
                        ndi_session_dir_obj.newdocument();
                    ndi_session_dir_obj.database_add(g);
                end
            end

            % BOTH VINTAGES. V_eta renames `syncgraph` to
            % `clock_alignment_policy`, whose class chain is [base] -- so an
            % `isa syncgraph` query against a migrated session matched
            % nothing, this fell into the isempty branch below, and the
            % session came up with a FRESH, RULE-LESS syncgraph while a real
            % one sat in the database. Silently: a session that opened fine
            % and had lost its synchronisation.
            syncgraph_doc = ndi_session_dir_obj.database_search( ndi.vintage.isaQuery('syncgraph') & ...
                ndi.query('base.session_id', 'exact_string', ndi_session_dir_obj.id(), ''));

            if isempty(syncgraph_doc)
                ndi_session_dir_obj.syncgraph = ndi.time.syncgraph(ndi_session_dir_obj);
            else
                if numel(syncgraph_doc)~=1
                    error(['Too many syncgraph documents found. Confused. There should be only 1.']);
                end
                ndi_session_dir_obj.syncgraph = ndi.database.fun.ndi_document2ndi_object(syncgraph_doc{1},ndi_session_dir_obj);
            end

            vlt.file.str2text([ndi_session_dir_obj.ndipathname() filesep 'reference.txt'], ...
                ndi_session_dir_obj.reference);
            vlt.file.str2text([ndi_session_dir_obj.ndipathname() filesep 'unique_reference.txt'], ...
                ndi_session_dir_obj.id());

            ndi_session_dir_obj.updateObjectTypeMarker();

            st = ndi.session.sessiontable();
            st.addtableentry(ndi_session_dir_obj.id(), ndi_session_dir_obj.path);
        end

        function p = getpath(ndi_session_dir_obj)
        % GETPATH - Return the path of the session
        %
        %   P = GETPATH(NDI_SESSION_DIR_OBJ)
        %
        % Returns the path of an ndi.session.dir object.
        %
        % The path is some sort of reference to the storage location of
        % the session. This might be a URL, or a file directory.
        %
            p = ndi_session_dir_obj.path;
        end

        function p = ndipathname(ndi_session_dir_obj)
        % NDIPATHNAME - Return the path of the NDI files within the session
        %
        % P = NDIPATHNAME(NDI_SESSION_DIR_OBJ)
        %
        % Returns the pathname to the NDI files in the ndi.session.dir object.
        %
        % It is the ndi.session.dir object's path plus [filesep '.ndi' ]

            ndi_dir = '.ndi';
            p = [ndi_session_dir_obj.path filesep ndi_dir ];
            if ~isfolder(p)
                mkdir(p);
            end
        end % ndipathname()

        function b = eq(ndi_session_dir_obj_a, ndi_session_dir_obj_b)
            % EQ - Are two ndi.session.dir objects equivalent?
            %
            % B = EQ(NDI_SESSION_DIR_OBJ_A, NDI_SESSION_DIR_OBJ_B)
            %
            % Returns 1 if the two ndi.session.dir objects have the same
            % path and reference fields. They do not have to be the same handles
            % (that is, have the same location in memory).
            %
            b = 0;
            if eq@ndi.session(ndi_session_dir_obj_a, ndi_session_dir_obj_b)
                b = strcmp(ndi_session_dir_obj_a.path,ndi_session_dir_obj_b.path);
            end
        end % eq()

        function inputs = creator_args(ndi_session_obj)
            % CREATOR_ARGS - return the arguments needed to build an ndi.session object
            %
            % INPUTS = CREATOR_ARGS(NDI_SESSION_OBJ)
            %
            % Return the inputs necessary to create an ndi.session object. Each input
            % argument is returned as an entry in the cell array INPUTS.
            %
            % Example:
            % INPUTS = ndi_session_obj.creator_args();
            % ndi_session_copy = ndi.session(INPUTS{:});
            %
            inputs{1} = ndi_session_obj.reference;
            inputs{2} = ndi_session_obj.getpath();
            inputs{3} = ndi_session_obj.id();
        end % creator_args()

        function obj_out = deleteSessionDataStructures(ndi_session_dir_obj, areYouSure, askUserToConfirm)
            % DELETESESSIONDATASTRUCTURES - delete the session files
            %
            % OBJ_OUT = DELETESESSIONDATASTRUCTURES(NDI_SESSION_DIR_OBJ, AREYOUSURE, ASKUSERTOCONFIRM)
            %
            % Deletes the session files (recursively removes .ndi directory).
            %
            % Inputs:
            %   AREYOUSURE (default false) - boolean, if true, proceeds with deletion without confirmation (unless ASKUSERTOCONFIRM is true and fails?)
            %       Actually, logic: if AREYOUSURE is true, we delete.
            %       If AREYOUSURE is false, we check ASKUSERTOCONFIRM.
            %   ASKUSERTOCONFIRM (default true) - boolean, if true and AREYOUSURE is false, asks user via popup.
            %
            % Returns:
            %   OBJ_OUT - ndi.session.dir.empty()
            %
            arguments
                ndi_session_dir_obj (1,1) ndi.session.dir
                areYouSure (1,1) logical = false
                askUserToConfirm (1,1) logical = true
            end

            % Check if ingested
            if ismethod(ndi_session_dir_obj, 'isIngestedInDataset')
                if ndi_session_dir_obj.isIngestedInDataset()
                    error('Cannot directly delete session that is embedded in dataset; use ndi.dataset.delete_session');
                end
            end

            passed = areYouSure;
            if ~passed && askUserToConfirm
                % We can only use questdlg if we have a display?
                % But typical usage is desktop.
                answer = questdlg('Are you sure you want to delete the session files?', 'Confirm Delete', 'Yes', 'No', 'No');
                if strcmp(answer, 'Yes')
                    passed = true;
                end
            end

            if passed
                p = fullfile(ndi_session_dir_obj.path, '.ndi');
                if isfolder(p)
                    % Close all open SQLite handles first so Windows will
                    % allow the did-sqlite.sqlite file to be deleted; an
                    % open file cannot be removed on Windows. dbid 0 closes
                    % every connection (mksqlite('close') closes only dbid 1,
                    % which may not be this session's); DID reopens lazily on
                    % the next operation (issue #870).
                    mksqlite(0, 'close');
                    rmdir(p, 's');
                end
                obj_out = ndi.session.dir.empty();
            else
                % If not passed, we return the object itself? Or empty?
                % "output object should be set to ndi.session.dir.empty()" was only specified "If the confirmation and the areYouSure pass".
                % If it fails, presumably we return the original object or nothing?
                % But the signature says we return `obj_out`.
                % If I return the original object, the user can continue using it.
                obj_out = ndi_session_dir_obj;
            end
        end

        function updateObjectTypeMarker(ndi_session_dir_obj)
            % UPDATEOBJECTTYPEMARKER - write/refresh the .ndi object-type marker file
            %
            % UPDATEOBJECTTYPEMARKER(NDI_SESSION_DIR_OBJ)
            %
            % Writes a small marker file in the session's .ndi directory that records
            % whether this directory holds a plain session or a dataset. The marker
            % lets a directory's type be determined quickly (for example, by a file
            % open dialog) without fully instantiating the object; see
            % ndi.session.dir.directorytype.
            %
            % A directory that already contains dataset bookkeeping documents
            % ('session_in_a_dataset' or the legacy 'dataset_session_info'), or that
            % has already been marked as a dataset, is (kept) marked as a dataset.
            % This prevents a session object from mislabeling a dataset directory as a
            % plain session -- important because an ndi.dataset.dir keeps an underlying
            % ndi.session.dir at the same path, and ingesting a session into a dataset
            % builds a temporary ndi.session.dir at the dataset's path.
            %
            % See also: ndi.session.dir/setObjectTypeMarker, ndi.session.dir.directorytype

            markerfile = [ndi_session_dir_obj.ndipathname() filesep ...
                ndi.session.dir.objecttypemarkerfilename()];

            existing_type = '';
            if isfile(markerfile)
                existing_type = lower(strtrim(vlt.file.textfile2char(markerfile)));
            end
            if strcmp(existing_type,'dataset')
                return; % never downgrade a directory already known to be a dataset
            end

            % Does this directory actually host a dataset? Datasets store
            % 'session_in_a_dataset' (current) or 'dataset_session_info' (legacy)
            % bookkeeping documents, or (v2) a session `included_in` a
            % `dataset` entity; standalone sessions never do. An empty dataset
            % has none of these yet, so it will be marked 'session' here and
            % corrected to 'dataset' by the ndi.dataset.dir constructor.
            % The database is searched WITHOUT this session's id filter
            % (database_search_with_dataset, not database_search; #1015,
            % #974): the bookkeeping documents carry the dataset's session id,
            % which need not be the session this object opened.
            is_dataset = ndi.session.dir.holdsDatasetRecords( ...
                @(q) ndi_session_dir_obj.database_search_with_dataset(q));

            if is_dataset
                ndi_session_dir_obj.setObjectTypeMarker('dataset');
            else
                ndi_session_dir_obj.setObjectTypeMarker('session');
            end
        end % updateObjectTypeMarker()

        function setObjectTypeMarker(ndi_session_dir_obj, typestr)
            % SETOBJECTTYPEMARKER - write the .ndi object-type marker file directly
            %
            % SETOBJECTTYPEMARKER(NDI_SESSION_DIR_OBJ, TYPESTR)
            %
            % Writes TYPESTR ('session' or 'dataset') to the object-type marker file
            % in the session's .ndi directory, unconditionally. Use this to force a
            % directory's recorded type; ndi.dataset.dir uses it to mark its directory
            % as a dataset. Most callers should use UPDATEOBJECTTYPEMARKER instead,
            % which chooses the type safely.
            %
            % See also: ndi.session.dir/updateObjectTypeMarker, ndi.session.dir.directorytype
            arguments
                ndi_session_dir_obj (1,1) ndi.session.dir
                typestr (1,:) char {mustBeMember(typestr,{'session','dataset'})}
            end
            markerfile = [ndi_session_dir_obj.ndipathname() filesep ...
                ndi.session.dir.objecttypemarkerfilename()];
            vlt.file.str2text(markerfile, typestr);
        end % setObjectTypeMarker()
    end % methods

    methods (Static)
        function tf = markedDataset(ndiPath)
            % MARKEDDATASET - does the .ndi folder NDIPATH carry the 'dataset' marker?
            %
            % TF = ndi.session.dir.markedDataset(NDIPATH) reads only the
            % object-type marker file (see OBJECTTYPEMARKERFILENAME), so it
            % answers for a folder that has no reference.txt yet, which
            % ndi.session.dir.directorytype does not.
            markerfile = fullfile(char(ndiPath), ndi.session.dir.objecttypemarkerfilename());
            tf = isfile(markerfile) && ...
                strcmpi(strtrim(vlt.file.textfile2char(markerfile)), 'dataset');
        end % markedDataset()

        function exists = exists(path)
            exists = false;
            files = dir(path);
            if any(contains({files(:).name},'.ndi'))
                files = dir(fullfile(path,'.ndi'));
                if any(contains({files(:).name},'reference.txt'))
                    exists = true;
                end
            end
        end % exists

        function tf = holdsDatasetRecords(search)
            % HOLDSDATASETRECORDS - does a database hold a dataset's own records?
            %
            % TF = ndi.session.dir.holdsDatasetRecords(SEARCH)
            %
            % SEARCH is a function handle taking an ndi.query and returning the
            % matching documents of a database WITHOUT any session id filter
            % (e.g. @(q) S.database_search_with_dataset(q), or an
            % ndi.database's search). TF is true when that database holds the
            % records only a dataset keeps:
            %
            %   v1: a 'session_in_a_dataset' or legacy 'dataset_session_info'
            %       document. Each carries the DATASET's session id
            %       (ndi.dataset/addSessionInfoToDataset), so a search scoped to
            %       a member session's id misses it (#1015, #974).
            %   v2: a `directed_relation` `included_in` (or `part_of`, the
            %       name a session migrated before the rename carries) whose
            %       parent is an entity of type dataset: a session or study
            %       filed under the dataset (did-schema
            %       did_v2_go_forward_class_audit.md, Jess Haley 2026-10-25
            %       [session membership records linked or ingested]).
            %
            % A search that errors on this database is read as "not found" for
            % that kind of record only.
            %
            % See also: ndi.session.dir/updateObjectTypeMarker, ndi.v2.datasetSessions
            tf = false;
            for c = {'session_in_a_dataset', 'dataset_session_info'}
                try
                    if ~isempty(search(ndi.query('', 'isa', c{1})))
                        tf = true;
                        return;
                    end
                catch
                end
            end
            try
                datasetDocs = search(ndi.v2.isaQuery('dataset'));
            catch
                datasetDocs = {};
            end
            for k = 1:numel(datasetDocs)
                p = datasetDocs{k}.document_properties;
                if ~strcmp(ndi.v2.kindOf(p), 'dataset')
                    continue;
                end
                try
                    rels = search(ndi.query('', 'isa', 'directed_relation', '') & ...
                        ndi.query('', 'depends_on', 'parent_id', p.base.id));
                catch
                    rels = {};
                end
                for r = 1:numel(rels)
                    rp = rels{r}.document_properties;
                    if ndi.v2.vocabIs('relation', ...
                            ndi.v2.blockOf(rp, 'directed_relation', 'relation', ''), ...
                            {'included_in', 'part_of'})
                        tf = true;
                        return;
                    end
                end
            end
        end % holdsDatasetRecords()

        function fname = objecttypemarkerfilename()
            % OBJECTTYPEMARKERFILENAME - filename of the .ndi object-type marker
            %
            % FNAME = ndi.session.dir.objecttypemarkerfilename()
            %
            % Returns the name of the marker file (within a directory's .ndi folder)
            % that records whether the directory holds a session or a dataset.
            %
            fname = 'ndi_object_type.txt';
        end % objecttypemarkerfilename()

        function t = directorytype(path)
            % DIRECTORYTYPE - quickly determine the NDI object type stored in a directory
            %
            % T = ndi.session.dir.directorytype(PATH)
            %
            % Inspects the .ndi folder of PATH and returns what kind of NDI object is
            % stored there, WITHOUT fully opening (instantiating) the object. This is
            % useful, for example, for a file-open dialog that must distinguish
            % datasets from sessions cheaply. T is one of:
            %
            %   'session' - PATH holds a standalone ndi.session
            %   'dataset' - PATH holds an ndi.dataset
            %   'unknown' - PATH is an NDI directory created before object-type markers
            %               existed; open it once with ndi.session.dir or
            %               ndi.dataset.dir to record its type. (An empty dataset that
            %               has never been opened since markers were introduced cannot
            %               be distinguished from a session without opening it.)
            %   'none'    - PATH is not an NDI session or dataset directory
            %
            % See also: ndi.session.dir.exists, ndi.dataset.dir.exists,
            %   ndi.session.dir/updateObjectTypeMarker
            t = 'none';
            if ~ndi.session.dir.exists(path)
                return;
            end
            markerfile = fullfile(char(path),'.ndi',ndi.session.dir.objecttypemarkerfilename());
            if isfile(markerfile)
                t = lower(strtrim(vlt.file.textfile2char(markerfile)));
                if ~any(strcmp(t,{'session','dataset'}))
                    t = 'unknown';
                end
                return;
            end
            t = 'unknown';
        end % directorytype

        function database_erase(ndi_session_dir_obj, areyousure)
            % DATABASE_ERASE - deletes the entire session database folder
            %
            % DATABASE_ERASE(NDI_SESSION_DIR_OBJ, AREYOUSURE)
            %
            %   Deletes the session in the database.
            %
            % Use with care. If AREYOUSURE is 'yes' then the
            % function will proceed. Otherwise, it will not.
            arguments
                ndi_session_dir_obj {mustBeA(ndi_session_dir_obj,'ndi.session.dir')}
                areyousure (1,:) char = 'no';
            end

            if strcmpi(areyousure,'yes')
                % Close all open SQLite handles first so Windows will allow the
                % did-sqlite.sqlite file to be deleted. dbid 0 closes every
                % connection (mksqlite('close') closes only dbid 1); DID
                % reopens lazily on the next operation (issue #870).
                mksqlite(0, 'close');
                rmdir(fullfile(ndi_session_dir_obj.path,'.ndi'),'s'); % remove database folder
            else
                disp('Not erasing session directory folder because user did not indicate they sure.');
            end
            delete(ndi_session_dir_obj);
        end % database_erase()

    end % methods (Static)

end % classdef
