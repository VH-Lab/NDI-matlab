classdef dataset < handle % & ndi.ido but this cannot be a superclass because it is not a handle; we do it by construction

    properties (GetAccess=protected, SetAccess = protected)
        session_info            % A structure with the sessions here
        session_array           % An array with session objects contained in the dataset
    end

    properties (Access = protected)
        session            % A session to hold documents for this dataset.
        % Note: This is not a session in the context of representing an
        % experimental session, but instead an entrypoint to a session-like
        % database.
    end

    methods

        function ndi_dataset_obj = dataset(reference)
            % ndi.dataset - Create a new ndi.dataset object
            %
            %   NDI_DATASET_OBJ=ndi.dataset(REFERENCE)
            %
            % Creates a new ndi.dataset object. The dataset has a unique
            % reference REFERENCE. This class is an abstract class and typically
            % an end user will open a specific subclass such as ndi.dataset.dir.
            %
            %   ndi.dataset/GETPATH, ndi.dataset/GETREFERENCE
        end

        function identifier = id(ndi_dataset_obj)
            % ID - return the identifier of an ndi.dataset object
            %
            % IDENTIFIER = ID(NDI_DATASET_OBJ)
            %
            % Returns the unique identifier of an ndi.dataset object.
            %
            identifier = ndi_dataset_obj.session.id();
        end % id()

        function ref = reference(ndi_dataset_obj)
            % reference - return the reference string for an ndi.dataset object
            %
            % REF_STRING = REFERENCE(NDI_DATASET_OBJ)
            %
            % Returns the reference string for an ndi.dataset object. This can be any
            % string, it is not necessarily unique among datasets. The dataset identifier
            % returned by ID is unique.
            %
            % See also: ndi.dataset/ID
            ref = ndi_dataset_obj.session.reference;
        end % unique_reference_string()

        function ndi_dataset_obj = add_linked_session(ndi_dataset_obj, ndi_session_obj)
            % ADD_LINKED_SESSION - link an ndi.session to an ndi.dataset
            %
            % NDI_DATASET_OBJ = ADD_LINKED_SESSION(NDI_DATASET_OBJ, NDI_SESSION_OBJ)
            %
            % Add an ndi.session object to an ndi.dataset, without ingesting the session
            % into the dataset. Instead, the ndi.session is linked to the dataset, but
            % the session remains where it is.
            %
            if isempty(ndi_dataset_obj.session_array)
                ndi_dataset_obj.build_session_info;
            end

            % first, make sure it is not already there

            match = any(strcmp(ndi_session_obj.id(),{ndi_dataset_obj.session_info.session_id}));
            if match
                error(['ndi.session object with id ' ndi_session_obj.id() ' is already part of dataset ' ndi_dataset_obj.id() '.']);
            end

            % okay, it is new, let's add it

            session_info_here.session_id = ndi_session_obj.id();
            session_info_here.session_reference = ndi_session_obj.reference();
            session_info_here.is_linked = 1;
            session_info_here.session_creator = class(ndi_session_obj);
            session_creator_args = ndi_session_obj.creator_args();
            for i=1:6 %numel(session_creator_args),
                field_here = ['session_creator_input' int2str(i)];
                session_info_here = setfield(session_info_here,field_here,'');
                if numel(session_creator_args)>=i
                    session_info_here = setfield(session_info_here,field_here,session_creator_args{i});
                end
            end

            % maybe later
            % assume that the second creator argument is a file path that needs to be made relative
            % session_info.session_creator_input2 = vlt.file.relativeFilename(ndi_dataset_obj.getpath(),ndi_session_obj.getpath)

            new_doc = ndi.dataset.addSessionInfoToDataset(ndi_dataset_obj, session_info_here);
            session_info_here.session_doc_in_dataset_id = new_doc.id();

            ndi_dataset_obj.session_info(end+1) = session_info_here;
            ndi_dataset_obj.session_array(end+1) = struct('session_id',ndi_session_obj.id(),'session',ndi_session_obj);

            mksqlite('close'); % TODO: update ndi.session with a close database files method                

        end % add_linked_session()

        % 01234567890123456789012345678901234567890123456789012345678901234567890123456789
        function ndi_dataset_obj = add_ingested_session(ndi_dataset_obj, ndi_session_obj)
            % ADD_INGESTED_SESSION - ingets an ndi.session into an ndi.dataset
            %
            % NDI_DATASET_OBJ = ADD_INGESTED_SESSION(NDI_DATASET_OBJ, NDI_SESSION_OBJ)
            %
            % Add an ndi.session object to an ndi.dataset, by copying the session
            % documents into the dataset.
            %
            if isempty(ndi_dataset_obj.session_array)
                ndi_dataset_obj.build_session_info;
            end

            % first, make sure it is not already there

            match = any(strcmp(ndi_session_obj.id(),{ndi_dataset_obj.session_info.session_id}));
            if match
                error(['ndi.session object with id ' ndi_session_obj.id() ' is already part of dataset ' ndi_dataset_obj.id() '.']);
            end

            % second, make sure it is fully ingested
            is_fully_ingested = ndi_session_obj.is_fully_ingested();
            if ~is_fully_ingested
                error(['ndi.session object with id ' ndi_session_obj.id() ' and reference ' ndi_session_obj.reference ' is not yet fully ingested. It must be fully ingested before it can be added in ingested form to an ndi.dataset object.']);
            end

            % okay, let's add it
            session_info_here.session_id = ndi_session_obj.id();
            session_info_here.session_reference = ndi_session_obj.reference;
            session_info_here.session_creator = class(ndi_session_obj);
            session_info_here.is_linked = 0;
            session_creator_args = ndi_session_obj.creator_args();
            for i=1:6 %numel(session_creator_args),
                field_here = ['session_creator_input' int2str(i)];
                session_info_here = setfield(session_info_here,field_here,'');
                if numel(session_creator_args)>=i
                    session_info_here = setfield(session_info_here,field_here,session_creator_args{i});
                end
            end

            % terrible kludge
            if isa(ndi_session_obj,'ndi.session.dir')
                session_info_here = setfield(session_info_here,'session_creator_input2',''); % same relative path % ndi_dataset_obj.getpath());
            else
                error(['Not smart enough to add ingested sessions of type ' class(ndi_session_obj) ' yet.']);
            end

            ndi.database.fun.copy_session_to_dataset(ndi_session_obj, ndi_dataset_obj);

            new_doc = ndi.dataset.addSessionInfoToDataset(ndi_dataset_obj, session_info_here);
            session_info_here.session_doc_in_dataset_id = new_doc.id();

            ndi_dataset_obj.session_info(end+1) = session_info_here;
            ndi_dataset_obj.session_array(end+1) = struct('session_id',ndi_session_obj.id(),'session',[]); % make it open it again

            mksqlite('close'); % TODO: update ndi.session with a close database files method                

        end % add_ingested_session()

        function ndi_session_obj = open_session(ndi_dataset_obj, session_id)
            % OPEN_SESSION - open an ndi.session object from an ndi.dataset
            %
            % NDI_SESSION_OBJ = OPEN_SESSION(NDI_DATASET_OBJ, SESSION_ID)
            %
            % Open an ndi.session object with session identifier SESSION_ID that is stored
            % in the ndi.dataset NDI_DATASET_OBJ.
            %
            % See also: ndi.session, ndi.dataset/session_list()
            %
            if isempty(ndi_dataset_obj.session_array)
                ndi_dataset_obj.build_session_info();
            end

            match = find(strcmp(session_id,{ndi_dataset_obj.session_array.session_id}));
            match_ = find(strcmp(session_id,{ndi_dataset_obj.session_info.session_id}));
            if isempty(match)
                error(['session_id ' session_id ' not found in dataset ' ...
                    ndi_dataset_obj.id() ]);
            else
                if ~isempty(ndi_dataset_obj.session_array(match).session)
                    ndi_session_obj = ndi_dataset_obj.session_array(match).session;
                else
                    patharg = ndi_dataset_obj.session_info(match_).session_creator_input2;
                    if ndi_dataset_obj.session_info(match_).is_linked==0
                        patharg = ndi_dataset_obj.getpath();
                    end
                    ndi_dataset_obj.session_array(match).session = ...
                        feval(ndi_dataset_obj.session_info(match_).session_creator,...
                        ndi_dataset_obj.session_info(match_).session_creator_input1, ...
                        patharg,...
                        session_id);
                    % ndi_dataset_obj.session_info(match_).session_creator_input3, ...
                    % ndi_dataset_obj.session_info(match_).session_creator_input4, ...
                    % ndi_dataset_obj.session_info(match_).session_creator_input5, ...
                    % ndi_dataset_obj.session_info(match_).session_creator_input6);
                    ndi_session_obj = ndi_dataset_obj.session_array(match).session;
                    mksqlite('close'); % TODO: update ndi.session with a close database files method                
                end
            end
        end % open_session()

        function [ref_list,id_list,session_doc_ids,dataset_session_doc_id] = session_list(ndi_dataset_obj)
            % SESSION_LIST - return the session reference/identifier list for a dataset
            %
            % [REF_LIST, ID_LIST, SESSION_DOC_IDS, DATASET_SESSION_DOC_ID] = SESSION_LIST(NDI_DATASET_OBJ)
            %
            % Returns information about ndi.session objects contained in an ndi.dataset
            % object NDI_DATASET_OBJ. REF_LIST is a cell array of reference strings, and
            % ID_LIST is a cell array of unique identifier strings. The nth entry of
            % REF_LIST corresponds to the Nth entry of ID_LIST (that is, REF_LIST{n} is the
            % reference that corresponds to the ndi.session with unique identifier ID_LIST{n}.
            %
            % SESSION_DOC_IDS is a cell array of the document unique ids for the 'session_in_a_dataset'
            % documents that describe the session in the dataset.
            %
            % DATASET_SESSION_DOC_ID is the document unique id for the 'session' document that
            % describes the dataset's own session.
            %
            if isempty(ndi_dataset_obj.session_info)
                ndi_dataset_obj.build_session_info();
            end

            ref_list = {ndi_dataset_obj.session_info.session_reference};
            id_list = {ndi_dataset_obj.session_info.session_id};
            session_doc_ids = {ndi_dataset_obj.session_info.session_doc_in_dataset_id};

            dataset_session_doc_id = '';
            q_dataset_session_doc = ndi.query('','isa','session') & ndi.query('base.session_id','exact_string',ndi_dataset_obj.id());
            doc = ndi_dataset_obj.session.database_search(q_dataset_session_doc);
            if numel(doc)==1
                dataset_session_doc_id = doc{1}.id();
            elseif numel(doc)>1
                error(['More than 1 session document for the dataset session found.']);
            end

        end % session_list()

        function p = getpath(ndi_dataset_obj)
            % GETPATH - Return the path of the dataset
            %
            %   P = GETPATH(NDI_DATASET_OBJ)
            %
            % Returns the path of an ndi.dataset object.
            %
            % The path is some sort of reference to the storage location of
            % the dataset. This might be a URL, or a file directory, depending upon
            % the subclass.
            %
            % In the ndi.dataset class, this returns empty.
            %
            % See also: ndidataset.
            p = ndi_dataset_obj.session.getpath();
        end

        % database methods

        function ndi_dataset_obj = database_add(ndi_dataset_obj, document)
            %DATABASE_ADD - Add an ndi.document to an ndi.dataset object
            %
            % NDI_DATASET_OBJ = DATABASE_ADD(NDI_DATASET_OBJ, NDI_DOCUMENT_OBJ)
            %
            % Adds the ndi.document NDI_DOCUMENT_OBJ to the ndi.dataset NDI_DATASET_OBJ.
            % NDI_DOCUMENT_OBJ can also be a cell array of ndi.document objects, which will
            % all be added in turn.
            %
            % If the base.session_id of each NDI_DOCUMENT_OBJ matches one of the sessions
            % in the DATASET, the document will be added to that session. If the base.session_id of
            % the document matches the id of the NDI_DATASET_OBJ, it will be added to the dataset
            % instead of one of the invidiual sessions.
            %
            % The database can be queried by calling NDI_DATASET_OBJ/SEARCH
            %
            % See also: ndi.dataset/database_search(), ndi.dataset/database_rm()
            if ~iscell(document)
                document = {document};
            end

            ndi_session_ids_here = {};
            for i=1:numel(document)
                ndi_session_ids_here{end+1} = document{i}.document_properties.base.session_id;
            end

            usession_ids = setdiff(unique(ndi_session_ids_here),ndi.session.empty_id());

            s = {};
            % make sure all documents have a home before doing anything else
            for i=1:numel(usession_ids)
                if ~strcmp(usession_ids{i},ndi_dataset_obj.id())
                    s{i} = ndi_dataset_obj.open_session(usession_ids{i});
                else
                    s{i} = ndi_dataset_obj.session;
                end
            end

            % now add them in turn
            for i=1:numel(usession_ids)
                indexes = find( strcmp(usession_ids{i},ndi_session_ids_here) | strcmp(ndi.session.empty_id(),ndi_session_ids_here));
                s{i}.database_add(document(indexes));
                mksqlite('close'); % TODO: update ndi.session with a close database files method                
            end
        end % database_add

        function ndi_dataset_obj = database_rm(ndi_dataset_obj, doc_unique_id, options)
            % DATABASE_RM - Remove an ndi.document with a given document ID from a dataset
            %
            % NDI_DATASET_OBJ = DATABASE_RM(NDI_DATASET_OBJ, DOC_UNIQUE_ID)
            %   or
            % NDI_DATASET_OBJ = DATABASE_RM(NDI_DATASET_OBJ, DOC)
            %
            % Removes an ndi.document with document id DOC_UNIQUE_ID from the
            % NDI_DATASET_OBJ database. In the second form, if an ndi.document or cell array
            % of NDI_DOCUMENTS is passed for DOC, then the document unique ids are retrieved
            % and they are removed in turn.  If DOC/DOC_UNIQUE_ID is empty, no action is
            % taken.
            %
            % If the base.session_id of each NDI_DOCUMENT_OBJ matches one of the linked sessions
            % in the DATASET, the document will be removed from the linked session. If the linked
            % session is opened individually, the document will have been removed.
            %
            % This function also takes parameters as name/value pairs that modify its behavior:
            % Parameter (default)        | Description
            % --------------------------------------------------------------------------------
            % ErrIfNotFound (false)      | Produce an error if an ID to be deleted is not found.
            %
            % See also: ndi.dataset/database_add(), ndi.dataset/database_search()

            arguments
                ndi_dataset_obj (1,1) {mustBeA(ndi_dataset_obj,"ndi.dataset")}
                doc_unique_id {mustBeA(doc_unique_id,["cell" "ndi.document","string","char"])}
                options.ErrIfNotFound (1,1) logical = false
            end

            doc_input = ndi.session.docinput2docs(ndi_dataset_obj, doc_unique_id); % make sure we have docs
            ndi_session_ids_here = {};
            for i=1:numel(doc_input)
                ndi_session_ids_here{i} = doc_input{i}.document_properties.base.session_id;
            end

            usession_ids = setdiff(unique(ndi_session_ids_here),ndi.session.empty_id());

            s = {};
            % make sure all documents have a home before doing anything else
            for i=1:numel(usession_ids)
                if ~strcmp(usession_ids{i},ndi_dataset_obj.id())
                    s{i} = ndi_dataset_obj.open_session(usession_ids{i});
                else
                    s{i} = ndi_dataset_obj.session;
                end
            end

            % now remove them in turn
            for i=1:numel(usession_ids)
                indexes = find( strcmp(usession_ids{i},ndi_session_ids_here) | strcmp(ndi.session.empty_id(),ndi_session_ids_here));
                s{i}.database_rm(doc_input(indexes),'ErrIfNotFound',options.ErrIfNotFound);
                mksqlite('close'); % TODO: update ndi.session with a close database files method                
            end
        end % database_rm

        function ndi_document_obj = database_search(ndi_dataset_obj, searchparameters)
            % DATABASE_SEARCH - Search for an ndi.document in a database of an ndi.dataset object
            %
            % NDI_DOCUMENT_OBJ = DATABASE_SEARCH(NDI_DATASET_OBJ, SEARCHPARAMETERS)T
            %
            % Given search parameters, which is an ndi.query object, the database associated
            % with the ndi.dataset object NDI_DATASET_OBJ is searched.
            %
            % Matches are returned in a cell list NDI_DOCUMENT_OBJ.
            %
            % See also: ndi.dataset/database_add(), ndi.dataset/database_rm()
            ndi_document_obj = ndi_dataset_obj.session.database.search(searchparameters);
            open_linked_sessions(ndi_dataset_obj);
            match = find([ndi_dataset_obj.session_info.is_linked]);
            for i=1:numel(match)
                ndi_document_obj = cat(2,ndi_document_obj,...
                    ndi_dataset_obj.session_array(match(i)).session.database_search(searchparameters));
                mksqlite('close'); % TODO: update ndi.session with a close database files method
            end
        end % database_search();

        function ndi_binarydoc_obj = database_openbinarydoc(ndi_dataset_obj, ndi_document_or_id, filename, options)
            % DATABASE_OPENBINARYDOC - open the ndi.database.binarydoc channel of an ndi.document
            %
            % NDI_BINARYDOC_OBJ = DATABASE_OPENBINARYDOC(NDI_DATASET_OBJ, NDI_DOCUMENT_OR_ID, FILENAME, ...)
            %
            %  Return the open ndi.database.binarydoc object that corresponds to an ndi.document and
            %  NDI_DOCUMENT_OR_ID can be either the document id of an ndi.document or an ndi.document object itself.
            %  The document is opened for reading only. Document binary streams may not be edited once the
            %  document is added to the database.
            %
            %  Note that this NDI_BINARYDOC_OBJ must be closed with ndi.dataset/CLOSEBINARYDOC.
            %
            %  This function takes name/value pairs that modify its behavior.
            %  Parameter (default)     | Description
            %  ------------------------------------------------------------------
            %  autoClose (true)       | Automatically close the file when the returned object goes out of scope.
            %
                arguments
                    ndi_dataset_obj
                    ndi_document_or_id
                    filename
                    options.autoClose (1,1) logical = true
                end
            ndi_binarydoc_obj = ndi_dataset_obj.session.database_openbinarydoc(ndi_document_or_id, filename, 'autoClose', options.autoClose);
        end % database_openbinarydoc

        function [tf, file_path] = database_existbinarydoc(ndi_dataset_obj, ndi_document_or_id, filename)
            % DATABASE_EXISTBINARYDOC - checks if an ndi.database.binarydoc exists for an ndi.document
            %
            % [TF, FILE_PATH] = DATABASE_EXISTBINARYDOC(NDI_DATASET_OBJ, NDI_DOCUMENT_OR_ID, FILENAME)
            %
            %  Return a boolean flag (TF) indicating if a binary document
            %  exists for an ndi.document and, if it exists, the full file
            %  path (FILE_PATH) to the file where the binary data is stored.

            [tf, file_path] = ndi_dataset_obj.session.database_existbinarydoc(ndi_document_or_id, filename);
        end

        function [ndi_binarydoc_obj] = database_closebinarydoc(ndi_dataset_obj, ndi_binarydoc_obj)
            % DATABASE_CLOSEBINARYDOC - close an ndi.database.binarydoc
            %
            % [NDI_BINARYDOC_OBJ] = DATABASE_CLOSEBINARYDOC(NDI_DATASET_OBJ, NDI_BINARYDOC_OBJ)
            %
            % Close and lock an NDI_BINARYDOC_OBJ. The NDI_BINARYDOC_OBJ must be unlocked in the
            % database, which is why it is necessary to call this function through the dataset object.
            %
            ndi_binarydoc_obj = ndi_dataset_obj.session.database_closebinarydoc(ndi_binarydoc_obj);
        end % database_closebinarydoc

        function ndi_session_obj = document_session(ndi_dataset_obj, ndi_document_obj)
            % DOCUMENT_SESSION return the ndi.session of an ndi.document object in an ndi.dataset
            %
            % NDI_SESSION_OBJ = DOCUMENT_SESSION(NDI_DATASET_OBJ, NDI_DOCUMENT_OBJ)
            %
            % Given an ndi.document, return an open ndi.session object that contains the
            % the document.
            %
            session_id = ndi_document_obj.document_properties.base.session_id;
            ndi_session_obj = ndi_dataset_obj.open_session(session_id)
        end % document_session()

    end % methods

    methods (Static)
        function [new_docs] = repairDatasetSessionInfo(ndi_dataset_obj, doc, options)
            % REPAIRDATASETSESSIONINFO - Break out dataset_session_info into individual session_in_a_dataset documents
            %
            % [NEW_DOCS] = ndi.dataset.repairDatasetSessionInfo(NDI_DATASET_OBJ, DOC, 'DryRun', [true|false])
            %
            % Checks to see if NDI_DATASET_OBJ has a dataset_session_info document. If so, it breaks
            % the information out into new individual session_in_a_dataset documents.
            %
            % DOC should be an ndi.document of type 'dataset_session_info'.
            %
            % If 'DryRun' is false (default), it deletes the dataset_session_info document and adds
            % the new session_in_a_dataset documents.
            %
            % If 'DryRun' is true, it only returns the new documents that would be added.

            arguments
                ndi_dataset_obj (1,1) {mustBeA(ndi_dataset_obj, 'ndi.dataset')}
                doc {mustBeA(doc,{'cell','ndi.document','did.document'})}
                options.DryRun (1,1) logical = false
            end

            new_docs = {};

            if ~iscell(doc)
                doc = {doc};
            end

            if numel(doc)>1
                 error(['Found too many dataset session info documents (' int2str(numel(doc)) ') for dataset ' ndi_dataset_obj.id() '.']);
            end

            currentDatasetID = doc{1}.document_properties.base.session_id;
            dataset_session_info_struct = doc{1}.document_properties.dataset_session_info.dataset_session_info;

            if isstruct(dataset_session_info_struct)
                 fields_to_copy = {'session_id','session_reference','is_linked','session_creator',...
                    'session_creator_input1','session_creator_input2','session_creator_input3',...
                    'session_creator_input4','session_creator_input5','session_creator_input6'};

                 for i = 1:numel(dataset_session_info_struct)
                     s = dataset_session_info_struct(i);
                     doc_struct = struct();
                     for f = 1:numel(fields_to_copy)
                        fn = fields_to_copy{f};
                        if isfield(s, fn)
                            doc_struct.(fn) = s.(fn);
                        else
                             if strcmp(fn, 'is_linked')
                                 doc_struct.(fn) = 0;
                             else
                                 doc_struct.(fn) = '';
                             end
                        end
                     end

                     new_doc = ndi.document('session_in_a_dataset', 'session_in_a_dataset', doc_struct);
                     new_doc = new_doc.set_session_id(currentDatasetID);
                     
                     new_docs{end+1} = new_doc;
                 end
            end

            if ~options.DryRun
                 if ~isempty(new_docs)
                     ndi_dataset_obj.database_add(new_docs);
                 end
                 ndi_dataset_obj.database_rm(doc{1});
            end
        end

        function new_doc = addSessionInfoToDataset(ndi_dataset_obj, session_info)
             % ADDSESSIONINFOTODATASET - Add a session_in_a_dataset document to the dataset
             %
             % NEW_DOC = ndi.dataset.addSessionInfoToDataset(NDI_DATASET_OBJ, SESSION_INFO)
             %
             % Creates a new 'session_in_a_dataset' document based on the SESSION_INFO structure
             % and adds it to the NDI_DATASET_OBJ's internal session database. The document's
             % base.session_id is set to the dataset's ID.

             new_doc = ndi.document('session_in_a_dataset', 'session_in_a_dataset', session_info);
             new_doc = new_doc.set_session_id(ndi_dataset_obj.id());
             ndi_dataset_obj.session.database_add(new_doc);
        end

        function removeSessionInfoFromDataset(ndi_dataset_obj, session_id)
             % REMOVESESSIONINFOFROMDATASET - Remove session_in_a_dataset document(s) for a given session ID
             %
             % ndi.dataset.removeSessionInfoFromDataset(NDI_DATASET_OBJ, SESSION_ID)
             %
             % Searches for 'session_in_a_dataset' documents that match the given SESSION_ID
             % (and belong to the dataset's session ID) and removes them from the database.

             q = ndi.query('session_in_a_dataset.session_id', 'exact_string', session_id) & ...
                 ndi.query('base.session_id', 'exact_string', ndi_dataset_obj.id());
             docs = ndi_dataset_obj.session.database_search(q);
             if ~isempty(docs)
                 ndi_dataset_obj.session.database_rm(docs);
             end
        end
    end % methods (Static)

    methods (Hidden)
        function [hCleanup, filename] = open_database(ndi_dataset_obj)
            [hCleanup, filename] = ndi_dataset_obj.session.open_database();
        end
    end

    methods (Access=protected)

        function build_session_info(ndi_dataset_obj)
            % BUILD_SESSION_INFO - build the session info data structure for an ndi.dataset
            %
            % BUILD_SESSION_INFO(NDI_DATASET_OBJ)
            %
            % Builds the internal variables 'session_array' and 'session_info' for
            % an ndi.dataset object.

            q = ndi.query('','isa','dataset_session_info') & ...
                ndi.query('base.session_id','exact_string',ndi_dataset_obj.id());
            session_info_doc = ndi_dataset_obj.session.database_search(q); % we know we are searching the dataset session

            if ~isempty(session_info_doc)
                % we have the old style, let's repair it
                ndi.dataset.repairDatasetSessionInfo(ndi_dataset_obj,session_info_doc);
            end

            q2 = ndi.query('','isa','session_in_a_dataset') & ...
                ndi.query('base.session_id','exact_string',ndi_dataset_obj.id());
            session_info_doc = ndi_dataset_obj.session.database_search(q2);

            ndi_dataset_obj.session_info = did.datastructures.emptystruct('session_id','session_reference','is_linked','session_creator',...
                    'session_creator_input1','session_creator_input2','session_creator_input3',...
                    'session_creator_input4','session_creator_input5','session_creator_input6','session_doc_in_dataset_id');

            for i=1:numel(session_info_doc)
                info_here = session_info_doc{i}.document_properties.session_in_a_dataset;
                info_here.session_doc_in_dataset_id = session_info_doc{i}.id();
                % fix field order, etc?
                ndi_dataset_obj.session_info(end+1) = info_here;
            end

            % now we have session_info structure, build the initial session_array

            ndi_dataset_obj.session_array = did.datastructures.emptystruct('session_id','session');
            for i=1:numel(ndi_dataset_obj.session_info)
                session_array_here.session_id = ndi_dataset_obj.session_info(i).session_id;
                session_array_here.session = []; % initially don't open it
                ndi_dataset_obj.session_array(i) = session_array_here; % entries will match
            end
        end % build_session_info()

        function open_linked_sessions(ndi_dataset_obj)
            % OPEN_LINKED_SESSIONS - ensure that all linked sessions are open
            %
            % OPEN_LINKED_SESSIONS(NDI_DATASET_OBJ)
            %
            % Open all linked dataset sessions, if they are not already open.
            %
            if isempty(ndi_dataset_obj.session_info)
                ndi_dataset_obj.build_session_info();
            end

            for i=1:numel(ndi_dataset_obj.session_info)
                if ndi_dataset_obj.session_info(i).is_linked
                    if isempty(ndi_dataset_obj.session_array(i).session)
                        ndi_dataset_obj.open_session(ndi_dataset_obj.session_info(i).session_id);
                        mksqlite('close'); % TODO: update ndi.session with a close database files method
                    end
                end
            end
        end % open_linked_sessions

    end % methods protected
end % class
