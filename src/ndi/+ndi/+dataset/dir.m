classdef dir < ndi.dataset

    properties (GetAccess=public, SetAccess=protected)
        path    % the file path of the session
    end

    methods
        function ndi_dataset_dir_obj = dir(reference, path_name, docs)
            % ndi.dataset.dir - Create a new ndi.dataset.dir object
            %
            % D = ndi.dataset.dir(REFERENCE, PATH_NAME)
            %
            % Creates an ndi.dataset.dir object, that is, an ndi.dataset object
            % with an associated directory.
            %
            % One can also create an existing ndi.dataset.dir object with
            %
            % D = ndi.dataset.dir(PATH_NAME)
            %
            if nargin==1
                path_name = reference;
                ndi.dataset.dir.mustNotBeSession(path_name);
                ndi_dataset_dir_obj.session = ndi.session.dir(path_name);
            elseif nargin==2
                ndi.dataset.dir.mustNotBeSession(path_name);
                ndi_dataset_dir_obj.session = ndi.session.dir(reference, path_name);
            elseif nargin==3 % hidden third option
                if iscell(docs) && isempty(docs)
                    ndi_dataset_dir_obj = ndi.dataset.dir(reference, path_name);
                    return;
                end
                % Todo: Switch off specific warnings using warning ids
                warningStruct = warning('off');
                resetWarningCleanupObj = onCleanup(@() warning(warningStruct));
                datasetSessionId = ndi.cloud.sync.internal.datasetSessionIdFromDocs(docs);
                ndi_dataset_dir_obj.session = ndi.session.dir(reference, path_name, datasetSessionId);
                mystruct = struct(ndi_dataset_dir_obj.session); % don't do this but we need to here
                mystruct.database.add(docs);
                clear resetWarningCleanupObj
                ndi_dataset_dir_obj.session = ndi.session.dir(reference, path_name);
            end

            % Use the session.dir's path as the path for this object
            ndi_dataset_dir_obj.path = ndi_dataset_dir_obj.session.path;

            dataset_session_info_docs = ndi_dataset_dir_obj.database_search(ndi.query('','isa','dataset_session_info'));
            
            correctSessionId = '';
            if ~isempty(dataset_session_info_docs)
                correctSessionId = dataset_session_info_docs{1}.document_properties.base.session_id;
            else
                q = ndi.query('','isa','session_in_a_dataset');
                session_in_a_dataset_docs = ndi_dataset_dir_obj.database_search(q);
                if ~isempty(session_in_a_dataset_docs)
                    correctSessionId = session_in_a_dataset_docs{1}.document_properties.base.session_id;
                else
                    q_session = ndi.query('','isa','session');
                    candidate_session_doc = ndi_dataset_dir_obj.database_search(q_session);
                    if isscalar(candidate_session_doc)
                       correctSessionId = candidate_session_doc{1}.document_properties.base.session_id;
                    end
                end
            end

            if ~isempty(correctSessionId)
                q_session = ndi.query('','isa','session') & ndi.query('base.session_id','exact_string',correctSessionId);                
                candidate_session_doc = ndi_dataset_dir_obj.database_search(q_session);
                if isscalar(candidate_session_doc)
                    ref = candidate_session_doc{1}.document_properties.session.reference;
                    session_id = candidate_session_doc{1}.document_properties.base.session_id;
                    ndi_dataset_dir_obj.session = ndi.session.dir(ref,ndi_dataset_dir_obj.session.path,session_id);
                else
                    error('Could not find dataset session document.');
                end
            else
                error('Could not find dataset session document.');
            end

            if ~isempty(dataset_session_info_docs)
                %disp('updating dataset to new form');
                % double-check we still need to do it
                dataset_session_info_docs2 = ndi_dataset_dir_obj.database_search(ndi.query('','isa','dataset_session_info'));
                if ~isempty(dataset_session_info_docs2)
                    ndi_dataset_dir_obj.repairDatasetSessionInfo(ndi_dataset_dir_obj,dataset_session_info_docs2);
                end
            end

            % Record on disk that this directory holds a dataset, so it can be
            % quickly distinguished from a plain session (for example, by an open
            % dialog) without opening it. Written unconditionally so that even an
            % empty dataset -- which has no session_in_a_dataset documents yet -- is
            % correctly marked, and so that older datasets are migrated the next time
            % they are opened. See ndi.session.dir.directorytype.
            ndi_dataset_dir_obj.session.setObjectTypeMarker('dataset');
        end % dir(), creator
    end % methods

    methods (Static, Access = protected)
        function mustNotBeSession(path)
            % MUSTNOTBESESSION - error if PATH holds a plain session, not a dataset
            %
            % ndi.dataset.dir.mustNotBeSession(PATH)
            %
            % Throws an error if PATH is a directory that holds a standalone
            % ndi.session rather than an ndi.dataset. This guards the
            % ndi.dataset.dir constructor against silently opening a session as a
            % dataset (which would otherwise succeed by falling back to the session's
            % own 'session' document and would then relabel the directory as a
            % dataset).
            %
            % The check uses the fast on-disk marker inspected by
            % ndi.session.dir.directorytype:
            %
            %   'dataset' - allowed (this is a dataset).
            %   'none'    - allowed (not yet an NDI directory; a new dataset can be
            %               created here).
            %   'session' - rejected.
            %   'unknown' - a legacy NDI directory whose type was never recorded.
            %               Because a marked session is caught but an *unmarked* one
            %               would slip through and be mislabeled, an 'unknown'
            %               directory is investigated before deciding: it is opened
            %               once as an ndi.session.dir, whose
            %               updateObjectTypeMarker inspects the directory's documents
            %               for dataset bookkeeping ('session_in_a_dataset' or the
            %               legacy 'dataset_session_info') and records 'dataset' when
            %               present, otherwise 'session'. The recorded type is then
            %               re-read and applied. A populated legacy dataset is thus
            %               correctly identified and allowed; an unmarked plain
            %               session is caught here rather than mislabeled.
            %
            % Fundamental limitation: an empty dataset stores no bookkeeping
            % documents and so is indistinguishable on disk from a plain session.
            % An empty *legacy* dataset (created empty before markers existed and
            % never opened since) is therefore recorded as a session and rejected;
            % open it once with ndi.session.dir, or re-create it, to record its
            % type. Empty datasets created normally are marked 'dataset' by the
            % ndi.dataset.dir constructor and are unaffected.
            %
            % See also: ndi.session.dir.directorytype,
            %   ndi.session.dir/updateObjectTypeMarker
            t = ndi.session.dir.directorytype(path);
            if strcmp(t,'unknown')
                % Migrate the marker by opening the directory once as a session,
                % then re-read the now-recorded type. If it cannot be opened to be
                % investigated, stay lenient (leave it 'unknown', i.e. allowed).
                try
                    ndi.session.dir(path);
                    t = ndi.session.dir.directorytype(path);
                catch
                    t = 'unknown';
                end
            end
            if strcmp(t,'session')
                error('NDI:dataset:dir:NotADataset', ...
                    ['The directory ''' char(path) ''' holds an ndi.session, not an ' ...
                    'ndi.dataset. Open it with ndi.session.dir instead.']);
            end
        end % mustNotBeSession()
    end % methods (Static, Access = protected)

    methods (Static)
        function b = exists(path)
            % EXISTS - does an ndi.dataset exist at a given path?
            %
            % B = ndi.dataset.dir.exists(PATH)
            %
            % Returns true if PATH holds an ndi.dataset directory, as determined by
            % ndi.session.dir.directorytype (which inspects the .ndi folder without
            % fully opening the object). Returns false for a plain session, for a
            % non-NDI directory, and for a legacy NDI directory whose type has not
            % yet been recorded (directorytype returns 'unknown'); open such a
            % directory once to record its type.
            %
            % See also: ndi.session.dir.exists, ndi.session.dir.directorytype
            arguments
                path {mustBeTextScalar}
            end
            b = strcmp(ndi.session.dir.directorytype(path),'dataset');
        end % exists()

        function dataset_erase(ndi_dataset_dir_obj, areyousure)
            % DATABASE_ERASE - deletes the entire session database folder
            %
            % DATABASE_ERASE(NDI_DATASET_DIR_OBJ, AREYOUSURE)
            %
            %   Deletes the session in the database.
            %
            % Use with care. If AREYOUSURE is 'yes' then the
            % function will proceed. Otherwise, it will not.
            arguments
                ndi_dataset_dir_obj {mustBeA(ndi_dataset_dir_obj,'ndi.dataset.dir')}
                areyousure (1,:) char = 'no';
            end

            if strcmpi(areyousure,'yes')
                rmdir(fullfile(ndi_dataset_dir_obj.path,'.ndi'),'s'); % remove database folder
            else
                disp('Not erasing session directory folder because user did not indicate they sure.');
            end
            delete(ndi_dataset_dir_obj);

        end % dataset_erase()
    end % methods (Static)
end
