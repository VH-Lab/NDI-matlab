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

            ndi_session_dir_obj.database = ndi.database.fun.opendatabase(...
                ndi_session_dir_obj.ndipathname(), ndi_session_dir_obj.id());

            read_from_database = 0;

            if should_we_try_to_read_from_database
                session_doc = ndi_session_dir_obj.database_search(ndi.query('','isa','session'));
                if ~isempty(session_doc)
                    % use the oldest
                    time_diff_max = 0;
                    time_loc = 0;
                    now_time = datetime('now','TimeZone','UTCLeapSeconds');
                    for i=1:numel(session_doc)
                        time_here = datetime(session_doc{i}.document_properties.base.datestamp,'TimeZone','UTCLeapSeconds');
                        time_diff_here = seconds(now_time-time_here);
                        if time_diff_here>time_diff_max
                            time_diff_max = time_diff_here;
                            time_loc = i;
                        end
                    end
                    session_doc = session_doc{time_loc};

                    ndi_session_dir_obj.identifier = session_doc.document_properties.base.session_id;
                    ndi_session_dir_obj.reference = session_doc.document_properties.session.reference;
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
                g = ndi.document('session','session.reference',ndi_session_dir_obj.reference) + ...
                    ndi_session_dir_obj.newdocument();
                ndi_session_dir_obj.database_add(g);
            end

            syncgraph_doc = ndi_session_dir_obj.database_search( ndi.query('','isa','syncgraph','') & ...
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
            % bookkeeping documents; standalone sessions never do. An empty dataset
            % has neither yet, so it will be marked 'session' here and corrected to
            % 'dataset' by the ndi.dataset.dir constructor.
            is_dataset = false;
            try
                d = ndi_session_dir_obj.database_search(ndi.query('','isa','session_in_a_dataset'));
                if isempty(d)
                    d = ndi_session_dir_obj.database_search(ndi.query('','isa','dataset_session_info'));
                end
                is_dataset = ~isempty(d);
            catch
                is_dataset = false;
            end

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
            %   ''        - PATH is not an NDI session or dataset directory
            %
            % See also: ndi.session.dir.exists, ndi.dataset.dir.exists,
            %   ndi.session.dir/updateObjectTypeMarker
            t = '';
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
                rmdir(fullfile(ndi_session_dir_obj.path,'.ndi'),'s'); % remove database folder
            else
                disp('Not erasing session directory folder because user did not indicate they sure.');
            end
            delete(ndi_session_dir_obj);
        end % database_erase()

    end % methods (Static)

end % classdef
