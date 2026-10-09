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

        % BinaryDocSessions - map from a live binarydoc's
        % fullpathfilename to the ndi.session that opened it. Populated
        % by database_openbinarydoc when a linked-session doc is
        % dispatched, and consulted by database_closebinarydoc so the
        % close goes to the same session's autoclose listener map and
        % database driver. Fixes #509: without this, close on the
        % dataset always went to session (the dataset's internal
        % session), leaking the lock on the linked session's DID store.
        %
        % Default is [] (not a containers.Map) so every dataset
        % instance gets its own map on first use in the helpers below.
        % A handle-typed default would have every dataset share the
        % SAME map -- Code Analyzer flags this and it is a real bug
        % when two datasets are open in the same MATLAB session.
        BinaryDocSessions = []

        % SessionNotes - a V2 dataset's session listing: its denominator and
        % every session left out and why (ndi.v2.datasetSessions). Read with
        % session_notes().
        SessionNotes = {}
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

        function ndi_dataset_obj = add_linked_session(ndi_dataset_obj, ndi_session_obj, options)
            % ADD_LINKED_SESSION - link an ndi.session to an ndi.dataset
            %
            % NDI_DATASET_OBJ = ADD_LINKED_SESSION(NDI_DATASET_OBJ, NDI_SESSION_OBJ, ...)
            %
            % Add an ndi.session object to an ndi.dataset, without ingesting the session
            % into the dataset. Instead, the ndi.session is linked to the dataset, but
            % the session remains where it is.
            %
            % In a V2 dataset (V_eta_linked_session_plan.md), this writes two
            % documents into the dataset's database: a `part_of` relation from
            % the session's `session` entity to the dataset (or to the study
            % 'PartOf' names), and a `linked_session` document recording the
            % session's folder (relative to the dataset's folder when inside it).
            % The session must be a V2 session.
            %
            % Options:
            %   'PartOf'  V2 only: the id of the dataset's study (an entity
            %             document in the dataset) the session is part_of;
            %             default: the dataset itself
            arguments
                ndi_dataset_obj (1,1) ndi.dataset
                ndi_session_obj (1,1) ndi.session
                options.PartOf (1,:) char = ''
            end
            if ndi_dataset_obj.v2Listing()
                ndi_dataset_obj.addSessionV2(ndi_session_obj, true, options.PartOf);
                return;
            end
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
        function ndi_dataset_obj = add_ingested_session(ndi_dataset_obj, ndi_session_obj, options)
            % ADD_INGESTED_SESSION - ingets an ndi.session into an ndi.dataset
            %
            % NDI_DATASET_OBJ = ADD_INGESTED_SESSION(NDI_DATASET_OBJ, NDI_SESSION_OBJ, ...)
            %
            % Add an ndi.session object to an ndi.dataset, by copying the session
            % documents into the dataset.
            %
            % This function accepts name/value pairs that alter its behavior:
            % Parameter (default)      | Description
            % -----------------------------------------------------------------
            % ReferenceInPlace (true)  | Copy each of the session's files
            %                          |   directly from its location in the
            %                          |   source session into the dataset,
            %                          |   without first staging a second copy
            %                          |   in a temporary directory. This
            %                          |   removes the transient 2x disk-space
            %                          |   requirement of the copy. Files that
            %                          |   are not on the local filesystem
            %                          |   (e.g. cloud-backed sessions) fall
            %                          |   back to staging automatically. Set
            %                          |   to false to force the old staged
            %                          |   copy. See
            %                          |   ndi.dataset.copySessionToDataset.
            % PartOf ('')              | V2 only: the id of the dataset's
            %                          |   study the session is part_of
            %                          |   (default: the dataset itself)
            %
            % In a V2 dataset (V_eta_linked_session_plan.md), every document of
            % the session is copied into the dataset's database, ids unchanged,
            % with the files it ingested; files recorded by location stay where
            % they are. Unless the copied documents already make the session
            % part_of the dataset or one of its studies, a `part_of` relation
            % is added. The session must be a V2 session.
            %
            arguments
                ndi_dataset_obj (1,1) ndi.dataset
                ndi_session_obj (1,1) ndi.session
                options.ReferenceInPlace (1,1) logical = true
                options.PartOf (1,:) char = ''
            end

            if ndi_dataset_obj.v2Listing()
                ndi_dataset_obj.addSessionV2(ndi_session_obj, false, options.PartOf);
                return;
            end

            if isempty(ndi_dataset_obj.session_array)
                ndi_dataset_obj.build_session_info;
            end

            % first, make sure it is not already there

            match = any(strcmp(ndi_session_obj.id(),{ndi_dataset_obj.session_info.session_id}));
            if match
                error(['ndi.session object with id ' ndi_session_obj.id() ' is already part of dataset ' ndi_dataset_obj.id() '.']);
            end

            % second, make sure it is fully ingested
            is_ingested = ndi_session_obj.isIngested();
            if ~is_ingested
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

            ndi.dataset.copySessionToDataset(ndi_session_obj, ndi_dataset_obj, ...
                'ReferenceInPlace', options.ReferenceInPlace);

            new_doc = ndi.dataset.addSessionInfoToDataset(ndi_dataset_obj, session_info_here);
            session_info_here.session_doc_in_dataset_id = new_doc.id();

            ndi_dataset_obj.session_info(end+1) = session_info_here;
            ndi_dataset_obj.session_array(end+1) = struct('session_id',ndi_session_obj.id(),'session',[]); % make it open it again

            mksqlite('close'); % TODO: update ndi.session with a close database files method                

        end % add_ingested_session()

        function ndi_dataset_obj = deleteIngestedSession(ndi_dataset_obj, session_id, options)
            % DELETEINGESTEDSESSION - delete an ingested session from the dataset
            %
            % NDI_DATASET_OBJ = DELETEINGESTEDSESSION(NDI_DATASET_OBJ, SESSION_ID, 'areYouSure', false, 'askUserToConfirm', true)
            %
            % Removes an ingested session from the dataset.
            %
            % The function removes the session_in_a_dataset document corresponding to the session,
            % and any document whose base.session_id matches the session_id to be deleted.
            %
            % WARNING: At present, this step is irreversible, because one cannot add back documents
            % to a dataset that have the same IDs as a previously-deleted dataset. This is a known
            % issue that may be solved in a future release but for now prevents deletion and
            % re-adding of the same ingested session. This issue does not impact linked sessions.
            %
            % Inputs:
            %   SESSION_ID - The ID of the session to delete.
            %   'areYouSure' - (Optional) Logical, default false. Must be true for the function to work.
            %   'askUserToConfirm' - (Optional) Logical, default true. If true, a question dialog will confirm the choice.
            %

            arguments
                ndi_dataset_obj (1,1) {mustBeA(ndi_dataset_obj,"ndi.dataset")}
                session_id (1,:) char
                options.areYouSure (1,1) logical = false
                options.askUserToConfirm (1,1) logical = true
            end

            if options.askUserToConfirm && ~options.areYouSure
                 answer = questdlg(sprintf('Are you sure you want to delete session %s? This is irreversible.', session_id), ...
                     'Confirm Deletion', 'Yes', 'No', 'No');
                 if strcmp(answer, 'Yes')
                     options.areYouSure = true;
                 end
            end

            if ~options.areYouSure
                error('ndi:dataset:deleteIngestedSession:notConfirmed', 'Deletion not confirmed.');
            end

            if isempty(ndi_dataset_obj.session_array)
                ndi_dataset_obj.build_session_info;
            end

            match_idx = find(strcmp(session_id, {ndi_dataset_obj.session_info.session_id}));
            if isempty(match_idx)
                 error('ndi:dataset:deleteIngestedSession:notFound', ['Session ' session_id ' not found in dataset.']);
            end

            if ndi_dataset_obj.session_info(match_idx).is_linked
                 error('ndi:dataset:deleteIngestedSession:isLinked', ['Session ' session_id ' is a linked session, not an ingested one.']);
            end

            session_doc_id = ndi_dataset_obj.session_info(match_idx).session_doc_in_dataset_id;

            % Find all documents with base.session_id == session_id
            q_docs = ndi.query('base.session_id', 'exact_string', session_id);
            docs_to_delete = ndi_dataset_obj.database_search(q_docs);

            % Delete session doc
            ndi_dataset_obj.database_rm(session_doc_id);

            % Delete other docs
            if ~isempty(docs_to_delete)
                 ndi_dataset_obj.database_rm(docs_to_delete);
            end

            % Rebuild session info
            ndi_dataset_obj.build_session_info();

        end % deleteIngestedSession()

        function b = isIngested(ndi_dataset_obj)
            % ISINGESTED - is a dataset fully ingested?
            %
            % B = ISINGESTED(NDI_DATASET_OBJ)
            %
            % Returns true if all sessions in the dataset are ingested,
            % and false otherwise. A dataset with no sessions is
            % considered ingested.

            if isempty(ndi_dataset_obj.session_info)
                ndi_dataset_obj.build_session_info();
            end

            if isempty(ndi_dataset_obj.session_info)
                b = true;
                return;
            end

            b = true;
            for i = 1:numel(ndi_dataset_obj.session_info)
                S = ndi_dataset_obj.open_session(ndi_dataset_obj.session_info(i).session_id);
                if ~S.isIngested()
                    b = false;
                    return;
                end
            end
        end % isIngested()

        function [b, cloudDatasetId] = isInCloud(ndi_dataset_obj)
            % ISINCLOUD - is this dataset linked to a dataset on NDI Cloud?
            %
            % [B, CLOUDDATASETID] = ISINCLOUD(NDI_DATASET_OBJ)
            %
            % Returns true if the dataset is linked to a remote dataset on
            % NDI Cloud, and false otherwise. A dataset is considered to be
            % "in the cloud" if its database contains a 'dataset_remote'
            % document. That document is created and stored locally the first
            % time the dataset is uploaded (see ndi.cloud.uploadDataset).
            %
            % This is a purely local check: it inspects only the dataset's own
            % database and performs NO network communication, so it does not
            % verify that the remote dataset still exists or is up to date. It
            % also does not open the dataset's linked sessions (the
            % 'dataset_remote' document lives in the dataset's own database, as
            % its base.session_id is the dataset id), so the check is cheap
            % enough to call while listing datasets.
            %
            % B is a logical scalar. CLOUDDATASETID is the remote NDI Cloud
            % dataset id (char) when B is true, or '' when B is false. If more
            % than one 'dataset_remote' document is present - which indicates a
            % misconfiguration - the id of the first is returned rather than
            % raising an error, so this status check never throws.
            %
            % See also: ndi.dataset/isIngested, ndi.cloud.uploadDataset,
            %   ndi.cloud.internal.getCloudDatasetIdForLocalDataset
            cloudDatasetId = '';
            q = ndi.query('', 'isa', 'dataset_remote');
            docs = ndi_dataset_obj.session.database.search(q);
            b = ~isempty(docs);
            if b
                cloudDatasetId = char(string( ...
                    docs{1}.document_properties.dataset_remote.dataset_id));
            end
        end % isInCloud()

        function unlink_session(ndi_dataset_obj, ndi_session_id, options)
            % UNLINK_SESSION - unlink a session from an ndi.dataset
            %
            % UNLINK_SESSION(NDI_DATASET_OBJ, NDI_SESSION_ID, 'areYouSure', false, ...)
            %
            % Unlinks a session from the dataset. The session must be a linked session (not ingested).
            %
            % Options:
            %  areYouSure (false) - must be true to proceed, unless confirmed by user
            %  askUserToConfirm (true) - if true, will ask user for confirmation via dialog (unless areYouSure is true)
            %  AlsoDeleteSessionAfterUnlinking (false) - if true, will also delete the session files
            %  DeleteSessionAskToConfirm (true) - passed to the session delete method
            %
            arguments
                ndi_dataset_obj (1,1) ndi.dataset
                ndi_session_id (1,:) char
                options.areYouSure (1,1) logical = false
                options.askUserToConfirm (1,1) logical = true
                options.AlsoDeleteSessionAfterUnlinking (1,1) logical = false
                options.DeleteSessionAskToConfirm (1,1) logical = true
            end

            if isempty(ndi_dataset_obj.session_info)
                ndi_dataset_obj.build_session_info();
            end

            match_idx = find(strcmp(ndi_session_id, {ndi_dataset_obj.session_info.session_id}), 1);

            if isempty(match_idx)
                error(['Session with ID ' ndi_session_id ' not found in dataset ' ndi_dataset_obj.id() '.']);
            end

            % Check if it is linked
            if ndi_dataset_obj.session_info(match_idx).is_linked == 0
                 error(['The session with ID ' ndi_session_id ' is an INGESTED session, not a linked session. Cannot unlink.']);
            end

            proceed = options.areYouSure;

            if ~proceed && options.askUserToConfirm
                 answer = questdlg(['Are you sure you want to unlink session ' ndi_session_id '?'], ...
                     'Confirm Unlink', ...
                     'Yes','No','No');
                 if strcmp(answer, 'Yes')
                     proceed = true;
                 end
            end

            if ~proceed
                 error('Operation not confirmed. Set areYouSure to true or confirm via dialog.');
            end

            if ndi_dataset_obj.v2Listing()
                % V2: the session leaves the dataset -- its linked_session
                % document and the part_of relations naming it go; its
                % folder is untouched
                session_obj = [];
                if options.AlsoDeleteSessionAfterUnlinking
                    session_obj = ndi_dataset_obj.open_session(ndi_session_id);
                end
                info = ndi_dataset_obj.session_info(match_idx);
                entityId = ndi_dataset_obj.v2EntityIdOf(match_idx);
                ids = [{info.session_doc_in_dataset_id}, ndi_dataset_obj.v2MembershipIds(entityId)];
                ndi_dataset_obj.v2Remove(ids);
                ndi_dataset_obj.build_session_info();
                if ~isempty(session_obj)
                    session_obj.deleteSessionDataStructures(options.areYouSure, options.DeleteSessionAskToConfirm);
                end
                return;
            end

            % If we need to delete the session later, we need the object.
            session_obj = [];
            if options.AlsoDeleteSessionAfterUnlinking
                % Try to find if it is already open
                if numel(ndi_dataset_obj.session_array) >= match_idx && ...
                        strcmp(ndi_dataset_obj.session_array(match_idx).session_id, ndi_session_id) && ...
                        ~isempty(ndi_dataset_obj.session_array(match_idx).session)
                    session_obj = ndi_dataset_obj.session_array(match_idx).session;
                else
                    % Open it
                    session_obj = ndi_dataset_obj.open_session(ndi_session_id);
                end
            end

            % Remove the session info (unlink)
            ndi.dataset.removeSessionInfoFromDataset(ndi_dataset_obj, ndi_session_id);

            % Rebuild info to update state
            ndi_dataset_obj.build_session_info();

            % Delete session if requested
            if options.AlsoDeleteSessionAfterUnlinking
                if ~isempty(session_obj)
                     % Pass areYouSure (which is true here) and DeleteSessionAskToConfirm
                     session_obj.deleteSessionDataStructures(options.areYouSure, options.DeleteSessionAskToConfirm);
                else
                    warning(['Could not open session ' ndi_session_id ' to delete it.']);
                end
            end

        end % unlink_session()

        function convertLinkedSessionToIngested(ndi_dataset_obj, session_id, options)
            % CONVERTLINKEDSESSIONTOINGESTED - convert a linked session to an ingested session
            %
            % CONVERTLINKEDSESSIONTOINGESTED(NDI_DATASET_OBJ, SESSION_ID, ...)
            %
            % Converts a linked session in the dataset to an ingested session by
            % copying all of its documents and binary files into the dataset. The
            % session must already be fully ingested (S.isIngested() must return true)
            % before conversion.
            %
            % After conversion, the session's data is self-contained within the
            % dataset and no longer depends on the original session path.
            %
            % Note: With ReferenceInPlace true (the default), each local file is
            % copied once, directly from the source session into the dataset, so
            % the operation requires only the space of the copy itself. Set
            % ReferenceInPlace false to force the old staged copy, which
            % temporarily requires approximately 2x the disk space of the
            % session being converted.
            %
            % Options:
            %   areYouSure (false) - must be true to proceed, unless confirmed by user
            %   askUserToConfirm (true) - if true, will ask user for confirmation via dialog
            %   ReferenceInPlace (true) - copy local files directly from the source
            %       into the dataset rather than staging a second copy in a
            %       temporary directory. See ndi.dataset.copySessionToDataset.
            %
            % See also: ndi.dataset/add_linked_session, ndi.dataset/add_ingested_session,
            %   ndi.dataset/unlink_session

            arguments
                ndi_dataset_obj (1,1) ndi.dataset
                session_id (1,:) char
                options.areYouSure (1,1) logical = false
                options.askUserToConfirm (1,1) logical = true
                options.ReferenceInPlace (1,1) logical = true
            end

            if isempty(ndi_dataset_obj.session_info)
                ndi_dataset_obj.build_session_info();
            end

            % Step 1: Find the session and verify it is linked

            match_idx = find(strcmp(session_id, {ndi_dataset_obj.session_info.session_id}), 1);

            if isempty(match_idx)
                error(['Session with ID ' session_id ' not found in dataset ' ndi_dataset_obj.id() '.']);
            end

            if ndi_dataset_obj.session_info(match_idx).is_linked == 0
                error(['Session with ID ' session_id ' is already an ingested session, not a linked session.']);
            end

            % Step 2: Open the session and verify it is fully ingested

            ndi_session_obj = ndi_dataset_obj.open_session(session_id);

            if ndi_dataset_obj.v2Listing()
                % V2 (V_eta_linked_session_plan.md): copy the session's
                % documents in, with the files they ingested, and delete the
                % linked_session document. The part_of relation stays.
                if ~ndi_dataset_obj.confirm(options, ['Are you sure you want to convert ' ...
                        'linked session ' session_id ' to an ingested session? This will copy ' ...
                        'all of its documents into the dataset.'], 'Confirm Conversion')
                    error('Operation not confirmed. Set areYouSure to true or confirm via dialog.');
                end
                linkId = ndi_dataset_obj.session_info(match_idx).session_doc_in_dataset_id;
                docs = ndi.v2.sessionDocuments(ndi_session_obj.database, session_id);
                ndi.v2.copyDocuments(ndi_session_obj.database.db, ndi_dataset_obj.v2Db(), docs);
                ndi_dataset_obj.v2Remove({linkId});
                ndi_dataset_obj.build_session_info();
                return;
            end

            if ~ndi_session_obj.isIngested()
                error(['Session with ID ' session_id ' and reference ' ...
                    ndi_session_obj.reference ' is not yet fully ingested. ' ...
                    'Call S.ingest() on the session before converting it.']);
            end

            % Step 3: Only ndi.session.dir is supported

            if ~isa(ndi_session_obj, 'ndi.session.dir')
                error(['Not smart enough to convert linked sessions of type ' class(ndi_session_obj) ' yet.']);
            end

            % Step 4: Confirm with user

            proceed = options.areYouSure;

            if ~proceed && options.askUserToConfirm
                answer = questdlg(['Are you sure you want to convert linked session ' session_id ...
                    ' to an ingested session? This will copy all data into the dataset.'], ...
                    'Confirm Conversion', ...
                    'Yes', 'No', 'No');
                if strcmp(answer, 'Yes')
                    proceed = true;
                end
            end

            if ~proceed
                error('Operation not confirmed. Set areYouSure to true or confirm via dialog.');
            end

            % Step 5: Copy all documents and binary files into the dataset.
            % Use skipDuplicateCheck because the session is already listed
            % as a linked session in session_list().

            ndi.dataset.copySessionToDataset(ndi_session_obj, ndi_dataset_obj, ...
                'skipDuplicateCheck', true, ...
                'ReferenceInPlace', options.ReferenceInPlace);

            % Step 6: Remove the old linked session_in_a_dataset document

            ndi.dataset.removeSessionInfoFromDataset(ndi_dataset_obj, session_id);

            % Step 7: Add a new session_in_a_dataset document with is_linked=0

            session_info_here.session_id = ndi_session_obj.id();
            session_info_here.session_reference = ndi_session_obj.reference;
            session_info_here.session_creator = class(ndi_session_obj);
            session_info_here.is_linked = 0;
            session_creator_args = ndi_session_obj.creator_args();
            for i=1:6
                field_here = ['session_creator_input' int2str(i)];
                session_info_here.(field_here) = '';
                if numel(session_creator_args) >= i
                    session_info_here.(field_here) = session_creator_args{i};
                end
            end
            % Clear the path so open_session uses the dataset path
            session_info_here.session_creator_input2 = '';

            new_doc = ndi.dataset.addSessionInfoToDataset(ndi_dataset_obj, session_info_here);
            session_info_here.session_doc_in_dataset_id = new_doc.id();

            % Step 8: Rebuild in-memory state

            ndi_dataset_obj.build_session_info();

            mksqlite('close'); % TODO: update ndi.session with a close database files method

        end % convertLinkedSessionToIngested()

        function convertIngestedSessionToLinked(ndi_dataset_obj, session_id, folder, options)
            % CONVERTINGESTEDSESSIONTOLINKED - move an ingested session out to its own folder
            %
            % CONVERTINGESTEDSESSIONTOLINKED(NDI_DATASET_OBJ, SESSION_ID, FOLDER, ...)
            %
            % V2 datasets only (V_eta_linked_session_plan.md). Writes every
            % document of the ingested session SESSION_ID into a new V2 session
            % in FOLDER, with the files they ingested (files recorded by
            % location stay where they are), deletes them from the dataset's
            % database, and adds a `linked_session` document naming FOLDER.
            % The `part_of` relations that make the session a member of the
            % dataset stay in the dataset's database. FOLDER must not already
            % hold an NDI database.
            %
            % Options:
            %   areYouSure (false) - must be true to proceed, unless confirmed by user
            %   askUserToConfirm (true) - if true, will ask user for confirmation via dialog
            %
            % See also: ndi.dataset/convertLinkedSessionToIngested,
            %   ndi.dataset/add_linked_session
            arguments
                ndi_dataset_obj (1,1) ndi.dataset
                session_id (1,:) char
                folder (1,:) char
                options.areYouSure (1,1) logical = false
                options.askUserToConfirm (1,1) logical = true
            end
            if ~ndi_dataset_obj.v2Listing()
                error('ndi:dataset:notV2', ...
                    'convertIngestedSessionToLinked works on a V2 dataset; this one is v1.');
            end
            if isempty(ndi_dataset_obj.session_info)
                ndi_dataset_obj.build_session_info();
            end
            match_idx = find(strcmp(session_id, {ndi_dataset_obj.session_info.session_id}), 1);
            if isempty(match_idx)
                error(['Session with ID ' session_id ' not found in dataset ' ndi_dataset_obj.id() '.']);
            end
            info = ndi_dataset_obj.session_info(match_idx);
            if info.is_linked
                error(['Session with ID ' session_id ' is already a linked session.']);
            end
            ndiDir = fullfile(folder, '.ndi');
            if isfolder(ndiDir) && ~isempty([dir(fullfile(ndiDir, '*.sqlite')); dir(fullfile(ndiDir, '*.json'))])
                error('ndi:dataset:folderTaken', '%s already holds an NDI database.', ndiDir);
            end
            if ~ndi_dataset_obj.confirm(options, ['Are you sure you want to move ingested session ' ...
                    session_id ' out of the dataset into ' folder '?'], 'Confirm Conversion')
                error('Operation not confirmed. Set areYouSure to true or confirm via dialog.');
            end

            entityId = info.session_doc_in_dataset_id;
            docs = ndi.v2.sessionDocuments(ndi_dataset_obj.session.database, session_id);
            stay = ndi_dataset_obj.v2MembershipIds(entityId);
            move = docs(~ismember(cellfun(@(d) d.base.id, docs, 'UniformOutput', false), stay));

            if ~isfolder(ndiDir), mkdir(ndiDir); end
            target = did2.database.sqlitedb(fullfile(ndiDir, ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()));
            ndi.v2.copyDocuments(ndi_dataset_obj.v2Db(), target, move);
            target.close();
            % the two files ndi.session.dir reads its id and reference from
            % (as ndi.setup.V2.createSession writes them)
            vlt.file.str2text(fullfile(ndiDir, 'unique_reference.txt'), session_id);
            vlt.file.str2text(fullfile(ndiDir, 'reference.txt'), info.session_reference);
            S = ndi.session.dir(folder);
            if ~strcmp(S.id(), session_id)
                error('ndi:dataset:moveMismatch', ...
                    'The session written to %s opened with id %s, not %s; the dataset is unchanged.', ...
                    folder, S.id(), session_id);
            end

            ndi_dataset_obj.v2Remove(cellfun(@(d) d.base.id, move, 'UniformOutput', false));
            link = did2.build.document('linked_session', ...
                struct('path', ndi.v2.linkPath(folder, ndi_dataset_obj.getpath())), ...
                'SessionId', ndi_dataset_obj.id(), 'Edges', struct('entity_id', entityId));
            ndi_dataset_obj.v2Db().add({did2.document(link)});
            ndi_dataset_obj.build_session_info();
        end % convertIngestedSessionToLinked()

        function report = makeSelfContained(ndi_dataset_obj, options)
            % MAKESELFCONTAINED - copy every file the dataset records by location into it
            %
            % REPORT = MAKESELFCONTAINED(NDI_DATASET_OBJ, ...)
            %
            % V2 datasets only (V_eta_linked_session_plan.md). A file is either
            % INGESTED (copied into the dataset's file store) or recorded BY
            % LOCATION (read where it is: raw recordings too large to copy).
            % This copies every by-location file of every document in the
            % dataset's database into the store and records it as ingested, so
            % the dataset no longer depends on those folders -- the step before
            % a dataset is shared. Linked sessions are not touched (their
            % documents are not in the dataset): convert them to ingested first.
            %
            % REPORT (printed first, the denominator first): documents inspected,
            % documents with a by-location file, files ingested, files whose
            % location holds nothing on this computer (left by location, each
            % named), locations that are not files (left), and linked sessions
            % not included.
            %
            % Options:
            %   'DryRun'  default false: true reports what would be copied and
            %             changes nothing
            arguments
                ndi_dataset_obj (1,1) ndi.dataset
                options.DryRun (1,1) logical = false
            end
            if ~ndi_dataset_obj.v2Listing()
                error('ndi:dataset:notV2', 'makeSelfContained works on a V2 dataset; this one is v1.');
            end
            if isempty(ndi_dataset_obj.session_info)
                ndi_dataset_obj.build_session_info();
            end
            db = ndi_dataset_obj.v2Db();
            ids = db.allIds();
            report = struct('documents', numel(ids), 'withByLocation', 0, 'ingested', 0, ...
                'missing', {{}}, 'notFiles', 0, ...
                'linkedSessions', sum([ndi_dataset_obj.session_info.is_linked]), ...
                'dryRun', options.DryRun);
            stage = tempname;
            for i = 1:numel(ids)
                d = db.get(ids{i}).toStruct();
                [d2, nIn, missing, notFiles, keep] = ingestByLocation(d, db.fileDir, stage);
                report.missing = [report.missing, missing];
                report.notFiles = report.notFiles + notFiles;
                if nIn == 0
                    continue;
                end
                report.withByLocation = report.withByLocation + 1;
                report.ingested = report.ingested + nIn;
                if options.DryRun
                    continue;
                end
                % a document's body cannot be changed in place: it is
                % removed and added again, its already-ingested files staged
                % first so removing it cannot lose them
                for k = 1:size(keep, 1)
                    if ~isfolder(stage), mkdir(stage); end
                    copyfile(keep{k, 1}, keep{k, 2});
                end
                db.remove(ids{i});
                db.add({did2.document(d2)}, 'Validate', false);
            end
            if isfolder(stage), rmdir(stage, 's'); end
            fprintf(['DENOMINATOR: %d document(s) inspected; %d with a by-location file; ' ...
                '%d file(s) %s; %d location(s) holding nothing here (left by location); %d ' ...
                'location(s) not a file (left); %d linked session(s) not included\n'], ...
                report.documents, report.withByLocation, report.ingested, ...
                ifelse(options.DryRun, 'would be ingested', 'ingested'), numel(report.missing), ...
                report.notFiles, report.linkedSessions);
            for k = 1:min(numel(report.missing), 20)
                fprintf('  nothing at: %s\n', report.missing{k});
            end
        end % makeSelfContained()

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
            q_dataset_session_doc = ndi.v2.isaQuery('session') & ndi.query('base.session_id','exact_string',ndi_dataset_obj.id());
            doc = ndi_dataset_obj.session.database_search(q_dataset_session_doc);
            if isscalar(doc)
                dataset_session_doc_id = doc{1}.id();
            elseif numel(doc)>1
                error('More than 1 session document for the dataset session found.');
            end

        end % session_list()

        function notes = session_notes(ndi_dataset_obj)
            % SESSION_NOTES - how a V2 dataset's sessions were listed
            %
            % NOTES = SESSION_NOTES(NDI_DATASET_OBJ)
            %
            % For a V2 dataset, a cellstr: the denominator of the listing
            % (session and linked_session documents read, sessions listed),
            % then every session left out and why -- a session document not
            % part_of the dataset, a linked folder that is missing or holds
            % another session. {} for a v1 dataset.
            %
            % See also: ndi.dataset/session_list, ndi.v2.datasetSessions
            if isempty(ndi_dataset_obj.session_info)
                ndi_dataset_obj.build_session_info();
            end
            notes = ndi_dataset_obj.SessionNotes;
        end % session_notes()

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

                doc_input = ndi.session.docinput2docs(ndi_dataset_obj, ndi_document_or_id);
                if ~isempty(doc_input)
                    doc = doc_input{1};
                    session_id = doc.document_properties.base.session_id;

                    % session matches one of the linked sessions
                    if ~strcmp(session_id, ndi_dataset_obj.id())
                        try
                            ndi_session_obj = ndi_dataset_obj.open_session(session_id);
                            ndi_binarydoc_obj = ndi_session_obj.database_openbinarydoc(doc, filename, 'autoClose', options.autoClose);
                            ndi_dataset_obj.rememberBinaryDocSession(ndi_binarydoc_obj, ndi_session_obj);
                            return;
                        catch
                            % if we can't open it or something goes wrong, fall back to current behavior
                        end
                    end
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

            doc_input = ndi.session.docinput2docs(ndi_dataset_obj, ndi_document_or_id);
            if ~isempty(doc_input)
                doc = doc_input{1};
                session_id = doc.document_properties.base.session_id;
                if ~strcmp(session_id, ndi_dataset_obj.id())
                    % session matches one of the linked sessions
                    % (actually docinput2docs found it, so it's either in dataset or linked session)
                    try
                        s = ndi_dataset_obj.open_session(session_id);
                        [tf, file_path] = s.database_existbinarydoc(doc, filename);
                        return;
                    catch
                        % if we can't open it or something goes wrong, fall back to current behavior
                    end
                end
            end

            [tf, file_path] = ndi_dataset_obj.session.database_existbinarydoc(ndi_document_or_id, filename);
        end

        function [ndi_binarydoc_obj] = database_closebinarydoc(ndi_dataset_obj, ndi_binarydoc_obj)
            % DATABASE_CLOSEBINARYDOC - close an ndi.database.binarydoc
            %
            % [NDI_BINARYDOC_OBJ] = DATABASE_CLOSEBINARYDOC(NDI_DATASET_OBJ, NDI_BINARYDOC_OBJ)
            %
            % Close and lock an NDI_BINARYDOC_OBJ. The NDI_BINARYDOC_OBJ must be
            % unlocked in the database, which is why it is necessary to call this
            % function through the dataset object.
            %
            % When database_openbinarydoc dispatched to a linked/member session
            % (because the doc's session_id was not the dataset's own), the
            % returned handle was remembered in BinaryDocSessions so this close
            % goes to that same session's database driver and autoclose listener
            % map. Without that lookup the close would always go to the dataset's
            % internal session and the linked session's DID lock would leak (#509).
            % Falls back to the internal session when no owning session is
            % recorded, matching prior behavior.
            owningSession = ndi_dataset_obj.lookupBinaryDocSession(ndi_binarydoc_obj);
            if isempty(owningSession)
                owningSession = ndi_dataset_obj.session;
            end
            ndi_dataset_obj.forgetBinaryDocSession(ndi_binarydoc_obj);
            ndi_binarydoc_obj = owningSession.database_closebinarydoc(ndi_binarydoc_obj);
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
            ndi_session_obj = ndi_dataset_obj.open_session(session_id);
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

        function [b,errmsg] = copySessionToDataset(ndi_session_obj, ndi_dataset_obj, options)
            % COPYSESSIONTODATASET - copy an ingested ndi.session to an ndi.dataset
            %
            % [B,ERRMSG] = ndi.dataset.copySessionToDataset(NDI_SESSION_OBJ, NDI_DATASET_OBJ)
            % [B,ERRMSG] = ndi.dataset.copySessionToDataset(..., 'skipDuplicateCheck', true)
            %
            % Copy the database documents of an ndi.session object to an ndi.dataset object.
            %
            % B is 1 if the operation succeeds and 0 otherwise. The copying process
            % temporarily requires 2 times the total disk space occupied by NDI_SESSION_OBJ,
            % and, long-term, requires 1 times the total disk space occupied by
            % NDI_SESSION_OBJ, which is stored in NDI_DATASET_OBJ.
            %
            % Options:
            %   skipDuplicateCheck (false) - If true, skip the check that prevents
            %       copying a session that is already in the dataset. Used internally
            %       by convertLinkedSessionToIngested when the session is already
            %       linked (and thus already appears in session_list) but its
            %       documents have not yet been copied.
            %   ReferenceInPlace (true) - If true, the session's files are copied
            %       directly from the source session into the dataset, without
            %       first staging a second copy in a temporary directory. This
            %       removes the transient 2x disk-space requirement (and the
            %       dependence on the volume that holds tempdir having room for
            %       the whole session). Files that are not on the local
            %       filesystem fall back to staging automatically. Set to false
            %       to force the old staged copy. See
            %       ndi.database.fun.extract_docs_files.
            %

            arguments
                ndi_session_obj (1,1) ndi.session
                ndi_dataset_obj (1,1) ndi.dataset
                options.skipDuplicateCheck (1,1) logical = false
                options.ReferenceInPlace (1,1) logical = true
            end

            b = 1;
            errmsg = '';

            % Step 1, check to make sure we haven't previously copied the documents

            if ~options.skipDuplicateCheck
                [~,session_ids] = ndi_dataset_obj.session_list();

                match = strcmp(ndi_session_obj.id(), session_ids);

                if any(match)
                    b = 0;
                    errmsg = ['Session with ID ' ndi_session_obj.id() ...
                        ' and reference ' ndi_session_obj.reference ...
                        ' is already a part of ndi.dataset with ID ' ...
                        ndi_dataset_obj.id() ' and reference ' ndi_dataset_obj.reference '.'];
                    return;
                end
            end

            % Step 2, make a copy of all the documents

            [docs,~] = ndi.database.fun.extract_docs_files(ndi_session_obj, '', ...
                'ReferenceInPlace', options.ReferenceInPlace);

            % what we want is to make a surrogate ndi.session.dir with path matching the dataset path
            % for this, we need to make sure the ndi.session.dir creator doesn't read its session_id or reference from the database
            % this needs to be true at ANY time, when it is opened again later

            are_empty_session_id_docs = 0;

            for i=1:numel(docs)
                if isempty(docs{i}.document_properties.base.session_id)
                    are_empty_session_id_docs = are_empty_session_id_docs + 1;
                    docs{i} = docs{i}.set_session_id(ndi_session_obj.id());
                end
            end

            if are_empty_session_id_docs>0
                warning(['Found ' int2str(are_empty_session_id_docs) ' documents with empty session_id. Setting them to match the current session.']);
            end

            ndi_session_surrogate = ndi.session.dir(ndi_session_obj.reference, ndi_dataset_obj.getpath(), ndi_session_obj.id());

            ndi_session_surrogate.database_add(docs);
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

            opened = {};
            if isempty(session_info_doc) && ndi_dataset_obj.isV2()
                % A V2 dataset records no session_in_a_dataset documents
                % (V_eta_linked_session_plan.md, signed 2026-10-09): a session
                % is in it when its `session` entity is `part_of` the dataset
                % or a study of it. INGESTED: its documents are in this
                % database, opened from the dataset's folder. LINKED: a
                % `linked_session` document names its folder, opened there.
                [v2, notes] = ndi.v2.datasetSessions(ndi_dataset_obj.session.database, ...
                    ndi_dataset_obj.id(), ndi_dataset_obj.getpath());
                ndi_dataset_obj.SessionNotes = notes;
                left = notes(startsWith(notes, 'not listed') | contains(notes, 'not part_of'));
                if ~isempty(left)
                    warning('ndi:dataset:sessionsLeftOut', '%s\n  %s', ...
                        'Some sessions of this dataset could not be listed:', strjoin(left, '\n  '));
                end
                for i = 1:numel(v2)
                    patharg = '';
                    docId = v2(i).entity_id;
                    if v2(i).is_linked
                        patharg = v2(i).path;
                        docId = v2(i).link_id;
                    end
                    info_here = struct('session_id', v2(i).session_id, ...
                        'session_reference', v2(i).reference, 'is_linked', double(v2(i).is_linked), ...
                        'session_creator', 'ndi.session.dir', ...
                        'session_creator_input1', v2(i).reference, ...
                        'session_creator_input2', patharg, 'session_creator_input3', '', ...
                        'session_creator_input4', '', 'session_creator_input5', '', ...
                        'session_creator_input6', '', 'session_doc_in_dataset_id', docId);
                    ndi_dataset_obj.session_info(end+1) = info_here;
                    opened{end+1} = v2(i).session; %#ok<AGROW>
                end
            elseif isempty(session_info_doc)
                % not a V2 database, and no session_in_a_dataset documents:
                % each other session document is an ingested session
                v2 = ndi_dataset_obj.session.database.search(ndi.v2.isaQuery('session'));
                for i=1:numel(v2)
                    p = v2{i}.document_properties;
                    [~, blk] = ndi.v2.kindOf(p);   % `entity` since 2026-10-08
                    if strcmp(p.base.session_id, ndi_dataset_obj.id()) || ~isfield(p.(blk),'local_identifier')
                        continue;
                    end
                    info_here = struct('session_id', p.base.session_id, ...
                        'session_reference', p.(blk).local_identifier, 'is_linked', 0, ...
                        'session_creator', 'ndi.session.dir', ...
                        'session_creator_input1', p.(blk).local_identifier, ...
                        'session_creator_input2', '', 'session_creator_input3', '', ...
                        'session_creator_input4', '', 'session_creator_input5', '', ...
                        'session_creator_input6', '', 'session_doc_in_dataset_id', v2{i}.id());
                    ndi_dataset_obj.session_info(end+1) = info_here;
                end
            end

            % now we have session_info structure, build the initial session_array

            ndi_dataset_obj.session_array = did.datastructures.emptystruct('session_id','session');
            for i=1:numel(ndi_dataset_obj.session_info)
                session_array_here.session_id = ndi_dataset_obj.session_info(i).session_id;
                session_array_here.session = []; % initially don't open it
                if i <= numel(opened)
                    session_array_here.session = opened{i}; % a linked session, opened to list it
                end
                ndi_dataset_obj.session_array(i) = session_array_here; % entries will match
            end
        end % build_session_info()

        function tf = isV2(ndi_dataset_obj)
            % ISV2 - is this dataset's database a V2 (did2) one?
            tf = isa(ndi_dataset_obj.session.database, ...
                'ndi.database.implementations.database.did2sqlite');
        end % isV2()

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

        function rememberBinaryDocSession(ndi_dataset_obj, ndi_binarydoc_obj, ndi_session_obj)
        %REMEMBERBINARYDOCSESSION Record which session opened a binarydoc.
        %   database_openbinarydoc calls this whenever it dispatches to
        %   a linked/member session, so that database_closebinarydoc can
        %   later route the close to that same session's autoclose
        %   listener map and database driver (#509). The key is the
        %   binarydoc's fullpathfilename -- the same key the session's
        %   autoclose map already uses, so lookups are cheap and stable
        %   across the binarydoc handle's lifetime.
            ndi_dataset_obj.ensureBinaryDocSessions();
            key = ndi_binarydoc_obj.fullpathfilename;
            ndi_dataset_obj.BinaryDocSessions(key) = ndi_session_obj;
        end % rememberBinaryDocSession

        function ndi_session_obj = lookupBinaryDocSession(ndi_dataset_obj, ndi_binarydoc_obj)
        %LOOKUPBINARYDOCSESSION Return the session that opened NDI_BINARYDOC_OBJ, or [].
            ndi_session_obj = [];
            if ~isa(ndi_dataset_obj.BinaryDocSessions, 'containers.Map')
                return;
            end
            key = ndi_binarydoc_obj.fullpathfilename;
            if isKey(ndi_dataset_obj.BinaryDocSessions, key)
                ndi_session_obj = ndi_dataset_obj.BinaryDocSessions(key);
            end
        end % lookupBinaryDocSession

        function forgetBinaryDocSession(ndi_dataset_obj, ndi_binarydoc_obj)
        %FORGETBINARYDOCSESSION Drop NDI_BINARYDOC_OBJ from the owning-session map.
            if ~isa(ndi_dataset_obj.BinaryDocSessions, 'containers.Map')
                return;
            end
            key = ndi_binarydoc_obj.fullpathfilename;
            if isKey(ndi_dataset_obj.BinaryDocSessions, key)
                remove(ndi_dataset_obj.BinaryDocSessions, key);
            end
        end % forgetBinaryDocSession

        function ensureBinaryDocSessions(ndi_dataset_obj)
        %ENSUREBINARYDOCSESSIONS Lazily create this instance's map.
        %   The BinaryDocSessions property defaults to [] so each
        %   ndi.dataset gets its own containers.Map here -- a handle
        %   default would have every dataset share the SAME map (Code
        %   Analyzer flags this and it is a real bug when two datasets
        %   are open concurrently).
            if ~isa(ndi_dataset_obj.BinaryDocSessions, 'containers.Map')
                ndi_dataset_obj.BinaryDocSessions = containers.Map( ...
                    'KeyType', 'char', 'ValueType', 'any');
            end
        end % ensureBinaryDocSessions

        % --- V2 datasets (V_eta_linked_session_plan.md) ---

        function tf = v2Listing(ndi_dataset_obj)
            % V2LISTING - are this dataset's sessions listed the V2 way?
            %   True for a did2 database holding no session_in_a_dataset
            %   document: membership is `part_of`, a linked session a
            %   `linked_session` document.
            tf = false;
            if ~ndi_dataset_obj.isV2()
                return;
            end
            q = ndi.query('', 'isa', 'session_in_a_dataset', '');
            tf = isempty(ndi_dataset_obj.session.database.search(q));
        end % v2Listing()

        function db = v2Db(ndi_dataset_obj)
            % V2DB - the dataset's did2.database.sqlitedb
            db = ndi_dataset_obj.session.database.db;
        end % v2Db()

        function v2Remove(ndi_dataset_obj, ids)
            % V2REMOVE - delete documents (by id) from the dataset's database
            db = ndi_dataset_obj.v2Db();
            for k = 1:numel(ids)
                if ~isempty(ids{k}) && db.has(ids{k})
                    db.remove(ids{k});
                end
            end
        end % v2Remove()

        function ids = v2MembershipIds(ndi_dataset_obj, entityId)
            % V2MEMBERSHIPIDS - the part_of relations in the dataset's database
            %   whose child is ENTITYID (the relations that make a session a
            %   member), as a cellstr of document ids
            ids = {};
            q = ndi.query('', 'isa', 'directed_relation', '') & ...
                ndi.query('', 'depends_on', 'child_id', entityId);
            rels = ndi_dataset_obj.session.database.search(q);
            for k = 1:numel(rels)
                p = rels{k}.document_properties;
                if strcmp(ndi.v2.termName(ndi.v2.blockOf(p, 'directed_relation', 'relation', '')), 'part_of')
                    ids{end+1} = p.base.id; %#ok<AGROW>
                end
            end
        end % v2MembershipIds()

        function tf = v2HasPartOf(ndi_dataset_obj, childId, parentId)
            % V2HASPARTOF - does the dataset's database hold CHILDID part_of PARENTID?
            tf = false;
            ids = ndi_dataset_obj.v2MembershipIds(childId);
            for k = 1:numel(ids)
                d = ndi_dataset_obj.session.database.search(ndi.query('base.id', 'exact_string', ids{k}, ''));
                if ~isempty(d) && any(strcmp(ndi.v2.edgeIds(d{1}.document_properties, 'parent_id'), parentId))
                    tf = true;
                    return;
                end
            end
        end % v2HasPartOf()

        function entityId = v2EntityIdOf(ndi_dataset_obj, idx)
            % V2ENTITYIDOF - the session entity id of session_info(IDX): the
            %   entity document itself for an ingested session, the
            %   linked_session's entity_id edge for a linked one
            info = ndi_dataset_obj.session_info(idx);
            entityId = info.session_doc_in_dataset_id;
            if info.is_linked
                d = ndi_dataset_obj.session.database.search( ...
                    ndi.query('base.id', 'exact_string', entityId, ''));
                e = ndi.v2.edgeIds(d{1}.document_properties, 'entity_id');
                entityId = e{1};
            end
        end % v2EntityIdOf()

        function addSessionV2(ndi_dataset_obj, ndi_session_obj, linked, partOf)
            % ADDSESSIONV2 - add a V2 session to a V2 dataset, linked or ingested
            if ~isa(ndi_session_obj.database, 'ndi.database.implementations.database.did2sqlite')
                error('ndi:dataset:notV2Session', ['Session %s is not a V2 session; only a ' ...
                    'V2 session can be added to a V2 dataset.'], ndi_session_obj.reference);
            end
            if linked && ~ndi.setup.V2.schemaHasClass('linked_session')
                error('ndi:dataset:noLinkedSessionClass', ['The schema in use has no ' ...
                    'linked_session class (V_eta_linked_session_plan.md), so a session cannot ' ...
                    'be linked to a V2 dataset with it.']);
            end
            if isempty(ndi_dataset_obj.session_info)
                ndi_dataset_obj.build_session_info();
            end
            if any(strcmp(ndi_session_obj.id(), {ndi_dataset_obj.session_info.session_id}))
                error(['ndi.session object with id ' ndi_session_obj.id() ...
                    ' is already part of dataset ' ndi_dataset_obj.id() '.']);
            end
            % the session's own `session` entity document
            own = ndi_session_obj.database_search(ndi.v2.isaQuery('session'));
            own = own(cellfun(@(d) strcmp(ndi.v2.kindOf(d.document_properties), 'session') && ...
                strcmp(d.document_properties.base.session_id, ndi_session_obj.id()), own));
            if ~isscalar(own)
                error('ndi:dataset:sessionDocument', ['Session %s holds %d session ' ...
                    'documents of its own; it must hold exactly one.'], ndi_session_obj.reference, ...
                    numel(own));
            end
            entityId = own{1}.id();
            % the parent it is part_of: the dataset, or a study of it
            dsid = ndi_dataset_obj.id();
            explicit = ~isempty(partOf);
            if ~explicit
                d = ndi_dataset_obj.session.database.search(ndi.v2.isaQuery('dataset'));
                d = d(cellfun(@(x) strcmp(ndi.v2.kindOf(x.document_properties), 'dataset'), d));
                if ~isscalar(d)
                    error('ndi:dataset:noDatasetDocument', ['The dataset holds %d dataset ' ...
                        'document(s), so ''PartOf'' must name the study the session is part_of.'], ...
                        numel(d));
                end
                partOf = d{1}.id();
            elseif isempty(ndi_dataset_obj.session.database.search(ndi.query('base.id', ...
                    'exact_string', partOf, '')))
                error('ndi:dataset:noSuchParent', ['''PartOf'' names %s, which is not a ' ...
                    'document of this dataset.'], partOf);
            end

            db = ndi_dataset_obj.v2Db();
            if ~linked
                docs = ndi.v2.sessionDocuments(ndi_session_obj.database, ndi_session_obj.id());
                here = cellfun(@(x) db.has(x.base.id), docs);
                if any(here)
                    error('ndi:dataset:documentsPresent', ['%d of the %d documents of session %s ' ...
                        'are already in the dataset.'], sum(here), numel(docs), ndi_session_obj.reference);
                end
                % a membership the session's own documents already state is
                % not stated again (each fact once, T17): with no 'PartOf',
                % its own part_of a study of the dataset (or the dataset) is
                % enough; with one, its own part_of that parent is
                parents = {};
                for k = 1:numel(docs)
                    p = docs{k};
                    if strcmp(char(p.document_class.class_name), 'directed_relation') && ...
                            any(strcmp(ndi.v2.edgeIds(p, 'child_id'), entityId)) && ...
                            strcmp(ndi.v2.termName(ndi.v2.blockOf(p, 'directed_relation', 'relation', '')), 'part_of')
                        parents = [parents, ndi.v2.edgeIds(p, 'parent_id')]; %#ok<AGROW>
                    end
                end
                if explicit
                    stated = ismember(partOf, parents);
                else
                    stated = ismember(partOf, parents) || ...
                        any(cellfun(@(x) ndi_dataset_obj.v2HasPartOf(x, partOf), parents));
                end
                ndi.v2.copyDocuments(ndi_session_obj.database.db, db, docs);
                if stated
                    ndi_dataset_obj.build_session_info();
                    return;
                end
            end
            add = {did2.build.directedRelation(entityId, partOf, 'part_of', 'SessionId', dsid)};
            if linked
                add{end+1} = did2.build.document('linked_session', ...
                    struct('path', ndi.v2.linkPath(ndi_session_obj.getpath(), ndi_dataset_obj.getpath())), ...
                    'SessionId', dsid, 'Edges', struct('entity_id', entityId));
            end
            db.add(cellfun(@(x) did2.document(x), add, 'UniformOutput', false));
            ndi_dataset_obj.build_session_info();
        end % addSessionV2()

    end % methods protected

    methods (Static, Access = protected)
        function tf = confirm(options, question, title)
            % CONFIRM - options.areYouSure, or the user's answer to a dialog
            tf = options.areYouSure;
            if ~tf && options.askUserToConfirm
                tf = strcmp(questdlg(question, title, 'Yes', 'No', 'No'), 'Yes');
            end
        end % confirm()
    end % methods (Static, Access = protected)
end % class

% -----------------------------------------------------------------------------
function [d, nIn, missing, notFiles, keep] = ingestByLocation(d, fileDir, stage)
% D with every by-location file location that holds a file here marked
% ingested; KEEP (N x 2: stored copy, staging path) the files D already
% ingested, pointed at their staging path so D can be removed and added back.
nIn = 0; missing = {}; notFiles = 0; keep = cell(0, 2);
if ~isfield(d, 'files') || ~isstruct(d.files) || ~isfield(d.files, 'file_info') ...
        || isempty(d.files.file_info)
    return;
end
fi = d.files.file_info;
if iscell(fi), fi = [fi{:}]; end
for a = 1:numel(fi)
    if ~isfield(fi(a), 'locations'), continue; end
    if iscell(fi(a).locations), fi(a).locations = [fi(a).locations{:}]; end
    for c = 1:numel(fi(a).locations)
        L = fi(a).locations(c);
        if isfield(L, 'ingest') && logical(L.ingest)
            staged = fullfile(stage, char(L.uid));
            keep(end+1, :) = {fullfile(fileDir, char(L.uid)), staged}; %#ok<AGROW>
            fi(a).locations(c).location = staged;
            fi(a).locations(c).delete_original = 1;
            continue;
        end
        type = 'file';
        if isfield(L, 'location_type') && ~isempty(L.location_type), type = lower(char(L.location_type)); end
        if ~strcmp(type, 'file')
            notFiles = notFiles + 1;
            continue;
        end
        if ~isfile(char(L.location))
            missing{end+1} = sprintf('%s of document %s (%s)', char(fi(a).name), d.base.id, ...
                char(L.location)); %#ok<AGROW>
            continue;
        end
        if ~isfield(L, 'uid') || isempty(L.uid) || ~did.file.isSafeUid(char(L.uid))
            fi(a).locations(c).uid = char(ndi.ido.unique_id());
        end
        fi(a).locations(c).ingest = 1;
        fi(a).locations(c).delete_original = 0;
        nIn = nIn + 1;
    end
end
d.files.file_info = fi;
end

function out = ifelse(tf, a, b)
if tf, out = a; else, out = b; end
end
