% NDI_SESSION_DIR - NDI_SESSION_DIR object class - an session with an associated file directory
%

classdef dir < ndi.session
    properties (GetAccess=public,SetAccess=protected)
        path    % the file path of the session
    end

    methods
        function ndi_session_dir_obj = dir(reference, path, session_id)
        % ndi.session.dir - Create a new ndi.session.dir ndi_session_dir_object
        %
        %   E = ndi.session.dir(REFERENCE, PATHNAME)
        %
        % Creates an ndi.session.dir ndi_session_dir_object, or an session with an
        % associated directory. REFERENCE should be a unique reference for the
        % session and directory PATHNAME.
        %
        % One can also open an existing session by using
        %
        %  E = ndi.session.dir(PATHNAME)
        %
        % See also: ndi.session, ndi.session.dir/GETPATH

            if nargin<2,
                path = reference;
                ref = 'temp';
            end

            if ~isfolder(path),
                error(['Directory ' path ' does not exist.']);
            end;

            ndi_session_dir_obj = ndi_session_dir_obj@ndi.session(reference);

            ndi_session_dir_obj.path = char(path); % Ensure type is character vector

            should_we_try_to_read_from_database = 1;

            if nargin>2, % we have the session_id % undocumented 3rd input argument
                ndi_session_dir_obj.identifier = session_id;
                ndi_session_dir_obj.reference = reference;
                should_we_try_to_read_from_database = 0;
            else,
                % next, figure out the ID; we won't use the one on disk unless we don't have a database entry

                d = dir([ndi_session_dir_obj.ndipathname() filesep 'unique_reference.txt']);
                if ~isempty(d),
                    ndi_session_dir_obj.identifier = strtrim(vlt.file.textfile2char(...
                        [ndi_session_dir_obj.ndipathname() filesep 'unique_reference.txt']));
                else,
                    % make a provisional new one
                    ndi_session_dir_obj.identifier = ndi.ido.unique_id();
                end
            end;

            ndi_session_dir_obj.database = ndi.database.fun.opendatabase(...
                ndi_session_dir_obj.ndipathname(), ndi_session_dir_obj.id());

            read_from_database = 0;

            if should_we_try_to_read_from_database,
                session_doc = ndi_session_dir_obj.database_search(ndi.query('','isa','session'));
                if ~isempty(session_doc),
                    % use the oldest
                    time_diff_max = 0;
                    time_loc = 0;
                    now_time = datetime('now','TimeZone','UTCLeapSeconds');
                    for i=1:numel(session_doc),
                        time_here = datetime(session_doc{i}.document_properties.base.datestamp,'TimeZone','UTCLeapSeconds');
                        time_diff_here = seconds(now_time-time_here);
                        if time_diff_here>time_diff_max,
                            time_diff_max = time_diff_here;
                            time_loc = i;
                        end;
                    end;
                    session_doc = session_doc{time_loc};

                    ndi_session_dir_obj.identifier = session_doc.document_properties.base.session_id;
                    ndi_session_dir_obj.reference = session_doc.document_properties.session.reference;
                    read_from_database = 1;
                end;
            end;

            if should_we_try_to_read_from_database & ~read_from_database,
                d = dir([ndi_session_dir_obj.ndipathname() filesep 'reference.txt']);
                if ~isempty(d),
                    ndi_session_dir_obj.reference = strtrim(vlt.file.textfile2char(...
                        [ndi_session_dir_obj.ndipathname() filesep 'reference.txt']));
                elseif nargin==1,
                    error(['Could not load the REFERENCE field from the database or path ' ndi_session_dir_obj.ndipathname() '.']);
                end
                % now we have both reference and id from either the files or the database, add it to db
                g = ndi.document('session','session.reference',ndi_session_dir_obj.reference) + ...
                    ndi_session_dir_obj.newdocument();
                ndi_session_dir_obj.database_add(g);
            end;

            syncgraph_doc = ndi_session_dir_obj.database_search( ndi.query('','isa','syncgraph','') & ...
                ndi.query('base.session_id', 'exact_string', ndi_session_dir_obj.id(), ''));

            if isempty(syncgraph_doc),
                ndi_session_dir_obj.syncgraph = ndi.time.syncgraph(ndi_session_dir_obj);
            else,
                if numel(syncgraph_doc)~=1,
                    error(['Too many syncgraph documents found. Confused. There should be only 1.']);
                end;
                ndi_session_dir_obj.syncgraph = ndi.database.fun.ndi_document2ndi_object(syncgraph_doc{1},ndi_session_dir_obj);
            end;

            vlt.file.str2text([ndi_session_dir_obj.ndipathname() filesep 'reference.txt'], ...
                ndi_session_dir_obj.reference);
            vlt.file.str2text([ndi_session_dir_obj.ndipathname() filesep 'unique_reference.txt'], ...
                ndi_session_dir_obj.id());

            st = ndi.session.sessiontable();
            st.addtableentry(ndi_session_dir_obj.id(), ndi_session_dir_obj.path);
        end;

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
        end;

        function p = ndipathname(ndi_session_dir_obj)
        % NDSPATHNAME - Return the path of the NDI files within the session
        %
        % P = NDIPATHNAME(NDI_SESSION_DIR_OBJ)
        %
        % Returns the pathname to the NDI files in the ndi.session.dir object.
        %
        % It is the ndi.session.dir object's path plus [filesep '.ndi' ]

            ndi_dir = '.ndi';
            p = [ndi_session_dir_obj.path filesep ndi_dir ];
            if ~isfolder(p),
                mkdir(p);
            end;
        end; % ndipathname()

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
            if eq@ndi.session(ndi_session_dir_obj_a, ndi_session_dir_obj_b),
                b = strcmp(ndi_session_dir_obj_a.path,ndi_session_dir_obj_b.path);
            end;
        end; % eq()

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
        end; % creator_args()
    end; % methods

end % classdef
