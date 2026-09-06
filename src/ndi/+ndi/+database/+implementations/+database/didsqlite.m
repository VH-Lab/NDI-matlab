classdef  didsqlite < ndi.database
    % didsqlite - a database based on sqlite

    properties
        db        % did.sqlitedb
    end

    methods

        function ndi_didsqlite_obj = didsqlite(varargin)
            % ndi.database.implementations.database.didsqlite make a new ndi.database.implementations.database.didsqlite object
            %
            % NDI_DIDSQLITE_OBJ = ndi.database.implementation.database.didsqlite(...
            %     PATH, SESSION_UNIQUE_REFERENCE, COMMAND, ...)
            %
            % Creates a new ndi.database.implementations.database.didsqlite object.
            %
            % COMMAND can either be 'Load' or 'New'. The second argument
            % should be the full pathname of the location where the files
            % should be stored on disk.
            %
            % See also: did.database, did.implementations.sqlitedb
            ndi_didsqlite_obj = ndi_didsqlite_obj@ndi.database(varargin{:});
            database_filename = fullfile(ndi_didsqlite_obj.path, 'did-sqlite.sqlite');
            ndi_didsqlite_obj.db = did.implementations.sqlitedb(database_filename);
            if ~isfolder(ndi_didsqlite_obj.file_directory)
                mkdir(ndi_didsqlite_obj.file_directory);
            end
            bid = ndi_didsqlite_obj.db.all_branch_ids();
            if isempty(bid)
                % No branches at all, so there is no current branch either,
                % and 'a' is necessarily a root. The parent argument is
                % omitted deliberately: since DID-matlab #164 an omitted or
                % empty parent means "the current branch", not "no parent",
                % so this guard is what makes 'a' a root rather than some
                % other branch's child. Do not widen it to a plain
                % ~ismember check.
                ndi_didsqlite_obj.db.add_branch('a');
            elseif ~ismember('a', bid)
                % The database exists and has branches, but not the one every
                % other method here hardcodes. Creating it now would attach it
                % to whatever the current branch happens to be, so say what is
                % wrong instead of leaving DID to raise
                % DID:Database:InvalidBranch on the next read.
                error('NDI:Database:MissingBranch', ...
                    ['The DID database at %s has branches %s but not ''a'', ' ...
                     'which ndi.database.implementations.database.didsqlite requires.'], ...
                    database_filename, strjoin(bid, ', '));
            end
        end % ndi.database.implementations.database.didsqlite()
    end

    methods % public
        function docids = alldocids(ndi_didsqlite_obj)
            % ALLDOCIDS - return all document unique reference numbers for the database
            %
            % DOCIDS = ALLDOCIDS(NDI_DIDSQLITE_OBJ)
            %
            % Return all document unique reference strings as a cell array of strings. If there
            % are no documents, empty is returned.
            %
            docids = ndi_didsqlite_obj.db.get_doc_ids('a');
        end % alldocids()
    end

    methods (Access=protected)

        function [hCleanup, filename] = do_open_database(ndi_didsqlite_obj)
            [hCleanup, filename] = ndi_didsqlite_obj.db.open();
        end

        function ndi_didsqlite_obj = do_add(ndi_didsqlite_obj, ndi_document_obj, add_parameters)
            % A file location marked for ingestion that is not a local path is
            % retrieved through the same handler do_openbinarydoc uses. DID
            % downloads nothing itself, so without this an ndic:// location
            % marked ingest cannot be fetched at add time. Remote ingestion is
            % rare -- ingest defaults to 0 for 'url' and 'ndicloud' locations.
            ndi_didsqlite_obj.db.add_docs(ndi_document_obj,'a', ...
                'customFileHandler', @download_file_from_cloud);
        end % do_add

        function [ndi_document_obj] = do_read(ndi_didsqlite_obj, ndi_document_id)
            [ndi_document_obj] = ndi_didsqlite_obj.db.get_docs(ndi_document_id);
            % now typecast to ndi.document from did.document
            if iscell(ndi_document_obj)
                for i=1:numel(ndi_document_obj)
                    ndi_document_obj{i} = ndi.document(ndi_document_obj{i});
                end
            else
                ndi_document_obj = ndi.document(ndi_document_obj);
            end
        end % do_read

        function ndi_didsqlite_obj = do_remove(ndi_didsqlite_obj, ndi_document_id, options)
            % did.database/remove_docs defaults to OnMissing='error'. NDI's
            % removals default to 'ignore' instead: a document someone else
            % already deleted still satisfies the request that it be gone.
            % Callers that need to hear about it pass ErrIfNotFound=1 to
            % ndi.session/database_rm, which maps to 'error' here.
            arguments
                ndi_didsqlite_obj
                ndi_document_id
                options.OnMissing {mustBeMember(options.OnMissing,{'ignore','warn','error'})} = 'ignore'
            end
            ndi_didsqlite_obj.db.remove_docs(ndi_document_id,'a', ...
                'OnMissing',options.OnMissing);
        end % do_remove

        function [ndi_document_objs] = do_search(ndi_didsqlite_obj, searchoptions, searchparams)
            if ~isa(searchparams,'ndi.query') & ~isa(searchparams,'did.query')
                error(['We need an ndi.query or did.query']);
            end

            ndi_document_objs = {};
            [doc_ids] = ndi_didsqlite_obj.db.search(searchparams,'a');
            ndi_document_objs = {};
            for i=1:numel(doc_ids)
                ndi_document_objs{i} = ndi_didsqlite_obj.do_read(doc_ids{i});
            end
        end % do_search()

        function [ndi_binarydoc_obj] = do_openbinarydoc(ndi_didsqlite_obj, ndi_document_id, filename)
            ndi_binarydoc_obj = ndi_didsqlite_obj.db.open_doc(ndi_document_id, filename, ...
                'customFileHandler', @download_file_from_cloud);
            ndi_binarydoc_obj.fopen(); % should be open but didsqlite does not open it
        end % do_openbinarydoc()

        function [tf, file_path] = check_exist_binarydoc(ndi_didsqlite_obj, ndi_document_id, filename)
            [tf, file_path] = ndi_didsqlite_obj.db.exist_doc(ndi_document_id, filename);
        end % check_exist_binarydoc()

        function [ndi_binarydoc_matfid_obj] = do_closebinarydoc(ndi_didsqlite_obj, ndi_binarydoc_matfid_obj)
            % DO_CLOSEBINARYDOC - close and unlock an NDI_BINARYDOC_MATFID_OBJ
            %
            % NDI_BINARYDOC_OBJ = DO_CLOSEBINARYDOC(NDI_DIDSQLITE_OBJ, NDI_BINARYDOC_MATFID_OBJ, KEY, NDI_DOCUMENT_ID)
            %
            % Close and unlock the binary file associated with NDI_BINARYDOC_OBJ.
            %
            ndi_didsqlite_obj.db.close_doc(ndi_binarydoc_matfid_obj);
        end % do_closebinarydoc()

        function [file_dir] = file_directory(ndi_didsqlite_obj)
            % FILE_DIRECTORY - return the file directory where ingested files are stored
            %
            % FILE_DIR = FILE_DIRECTORY(NDI_DIDSQLITE_OBJ)
            %
            % Return the full path of the directory where binary files for the database documents
            % are stored.
            %
            file_dir = [ndi_didsqlite_obj.path filesep 'files'];
        end % file_directory
    end
end

function download_file_from_cloud(destPath, sourcePath, context)
    % DOWNLOAD_FILE_FROM_CLOUD - retrieve an ndic:// file for DID
    %
    % DOWNLOAD_FILE_FROM_CLOUD(DESTPATH, SOURCEPATH, [CONTEXT])
    %
    % Satisfies did.database's customFileHandler contract: retrieve the file
    % identified by SOURCEPATH and leave it at DESTPATH. SOURCEPATH must be an
    % 'ndic://<datasetId>/<fileUid>' reference; the download URL is minted
    % fresh here because pre-signed URLs expire, which is why documents store
    % the durable identifier rather than a URL.
    %
    % CONTEXT is the per-call struct DID's dispatchCustomFileHandler passes
    % when a handler declares three or more inputs (DID-matlab#186): it
    % carries the caller's documentId and, for a series member, the
    % series name and the MEMBER'S OWN UID. When present those are used to
    % look the uid up in a per-document signed-URL cache -- one API round
    % trip per DOCUMENT (or per fileSeries scope) instead of one per uid,
    % closing DID #173's step 3 for the read path. Falls back to per-uid
    % getFileDetails when no context is given or the batch call cannot
    % answer -- so a 2-arg handler-shaped caller, and any uid missing
    % from the batch response, still work.
    %
    % WHICH UID IS BEING ASKED FOR. On an ordinary file, SOURCEPATH names
    % it and its uid is the one in the ndic:// reference. On a SERIES
    % MEMBER it is not: a member has no location of its own, so DID passes
    % the SERIES MANIFEST's location as SOURCEPATH and names the member in
    % context.uid (DID-matlab#188), with context.seriesName marking that it
    % is a member at all. Parsing the uid out of SOURCEPATH there
    % fetches the manifest a second time and stores it under the member's
    % uid, so every later read of that member returns the manifest --
    % quietly, and forever. DID guards against exactly this, comparing what
    % a handler returns against the manifest it already holds and refusing
    % a match with DID:SQLITEDB:FileSeries:HandlerReturnedManifest, which is
    % what this handler tripped on every member fetch before the context
    % was read. So the member's uid comes from the context; every other
    % call still takes it from sourcePath.
    %
    % Previously a nested function inside do_openbinarydoc. It is file-local so
    % that do_add can pass the same handler.

    if nargin < 3
        context = struct();
    end

    if startsWith(sourcePath, 'ndic://')
        cloudPath = split( extractAfter(sourcePath, 'ndic://'), "/" );
        cloudDatasetId = cloudPath{1};
        ndiFileUid = cloudPath{2};

        % Try the per-document batch cache first. Empty documentId
        % (2-arg dispatch, or an older DID) makes this a no-op that
        % returns "".
        [docId, seriesName, contextUid] = readContext(context);

        % Take the uid from the context only for a SERIES MEMBER, which is
        % what a non-empty seriesName marks. There sourcePath's uid is
        % definitively the wrong one -- it names the manifest -- so there is
        % nothing to weigh.
        %
        % Deliberately not "prefer context.uid whenever it is present". On an
        % ordinary file DID also passes a uid (its files-table row), and it
        % should equal the one in the ndic:// location, since
        % updateFileInfoForRemoteFiles builds that location out of
        % locations(1).uid. Should. If the two ever disagreed, the ndic://
        % one is the identifier the CLOUD was told about and the one a URL
        % can be minted for, so the context's would be the wrong uid to ask
        % with -- and this is the live download path for every file NDI
        % fetches, not just series members. Confining the change to the case
        % that is broken leaves the case that works alone.
        if strlength(seriesName) > 0 && strlength(contextUid) > 0
            ndiFileUid = char(contextUid);
        end
        fileUrl = ndi.cloud.download.internal.batchSignedUrlLookup( ...
            string(cloudDatasetId), docId, seriesName, string(ndiFileUid));

        if strlength(fileUrl) == 0
            % No batch URL for this uid -- either no document context,
            % or the batch call failed, or the returned map did not name
            % this uid. Fall back to the per-uid mint, which is exactly
            % what this handler did before #952.
            [success, answer, ~] = ndi.cloud.api.files.getFileDetails(cloudDatasetId, ndiFileUid);
            if ~success
                error(['Failed to get file details: ' answer.message]);
            end
            fileUrl = answer.downloadUrl;
        end
        [success2, answer2] = ndi.cloud.api.files.getFile(char(fileUrl), destPath, 'useCurl', true);
        if ~success2
            error(['Failed to download file from cloud: ' answer2]);
        end
    else
        error('NDI:Didsqlite:UnsupportedFileLocationType', ...
            ['The source path "%s" uses an unsupported file location type. ' ...
            'Expected a path starting with "ndic://".'], ...
            sourcePath);
    end
end

function [docId, seriesName, uid] = readContext(context)
    % Pull documentId, seriesName and uid from the DID handler context, if
    % the fields are present. Missing values become "" so the batch
    % lookup can treat them uniformly, and so the caller can test uid
    % with strlength rather than a field check of its own.
    docId = "";
    seriesName = "";
    uid = "";
    if isstruct(context)
        if isfield(context,'documentId') && ~isempty(context.documentId)
            docId = string(context.documentId);
        end
        if isfield(context,'seriesName') && ~isempty(context.seriesName)
            seriesName = string(context.seriesName);
        end
        if isfield(context,'uid') && ~isempty(context.uid)
            uid = string(context.uid);
        end
    end
end
