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
                ndi_dataset_dir_obj.session = ndi.session.dir(path_name);
            elseif nargin==2
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
                ndi_dataset_dir_obj.repairDatasetSessionInfo(ndi_dataset_dir_obj,dataset_session_info_docs);
            end
        end % dir(), creator
    end % methods

    methods (Static)
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
                ndi_dataset_dir_obj {mustBeA(ndi_dataset_dir_obj,'ndi.session.dir')}
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
