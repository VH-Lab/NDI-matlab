classdef SessionWriter < handle
% NDI.CLOUD.UPLOAD.SESSIONWRITER - add documents straight to a session of an NDI Cloud dataset
%
%   W = ndi.cloud.upload.SessionWriter(CLOUDDATASETID, SESSIONID)
%
%   Stands in for an ndi.session that lives in an NDI Cloud dataset, so a
%   document builder that writes to a session can write to the cloud
%   instead, with no local session or dataset in between. The builders in
%   ndi.fun.doc.lightsheet take one in place of a session:
%
%     W = ndi.cloud.upload.SessionWriter(cloudDatasetId, sessionId);
%     ndi.fun.doc.lightsheet.fromOMEZarr(W, '/data/brain.ome.zarr', ...
%         'subjectID', subjectId);
%
%   A DOCUMENT GOES TO A SESSION, NOT TO A DATASET. SESSIONID must be the
%   id of a session in the dataset (one of its session_in_a_dataset
%   records); the constructor refuses anything else. Every document added
%   gets that id as base.session_id, exactly as ndi.session/database_add
%   would give it, so the documents are found in that session when the
%   dataset is downloaded. ndi.cloud.upload.SessionWriter.listSessions
%   lists the sessions a dataset has.
%
%   WHAT IT DEPENDS ON MUST ALREADY BE THERE. A document's dependencies
%   must be documents added through this writer or documents already in
%   the cloud dataset; a subject_id must name a subject in this same
%   session (REQUIRESUBJECT). Both are checked before any of the
%   document's files are sent.
%
%   FILES FIRST, CHECKED, THEN DOCUMENTS. DATABASE_ADD sends the
%   document's files and file-series members at once, each under the uid
%   DID gave it (the uid a local session would store it under, so the
%   cloud copy is indistinguishable from one uploadDataset made). It then
%   asks NDI Cloud for each file's recorded CRC-32 (ndi.fun.file.crc32's
%   encoding) and compares it with the local one, or the size when the
%   cloud recorded no checksum. A file that is missing or differs is sent
%   again on its own with a signed checksum, which S3 refuses to store
%   wrong; one still missing or different after that is an error. The
%   document itself is held back until COMMIT, so a run that fails part
%   way leaves no document in the cloud pointing at files that are not
%   there.
%
%   STREAMING A FILE SERIES. A document whose series is built over
%   hours (a lightsheet pyramid level) is not added with DATABASE_ADD but
%   DECLAREd: it is uploaded at once with every member's uid already in
%   its manifest, so nothing in the cloud is ever unreferenced, and the
%   members are then sent in batches as they are made (STREAMMEMBERS).
%   Each batch is checked against the cloud while the next is built, and
%   its local copies are deleted once it checks out -- unless a later
%   step reads them back (RETAIN), in which case RELEASEMEMBERS deletes
%   them when that step is done. COMMIT checks that every declared member
%   arrived. ndi.fun.doc.lightsheet.makePyramid streams this way.
%
%   LOCAL COPIES. Each file is moved (or copied, when its document says
%   not to delete the original) into CACHEDIR before it is sent. Files of
%   a DATABASE_ADD document stay there until COMMIT, so a builder can
%   read back what it wrote; streamed members stay only as long as
%   described above. A file no longer cached is downloaded on demand.
%
%   SENDING IN THE BACKGROUND. A batch of files too small for a zip
%   batch is sent by one curl process in the background
%   (ndi.cloud.upload.CurlSender), PARALLELUPLOADS files at a time, while
%   MATLAB goes on building the next batch; it is waited for when it is
%   checked. Where curl is too old for that (before 7.68), or
%   PARALLELUPLOADS is 1, files are sent one by one, as before.
%
%   Optional Name-Value Arguments:
%   Verbose         - print progress lines. Default true.
%   ParallelUploads - files a batch sends at once, in the background.
%                     Default 4. 1 sends them one by one, and waits.
%   BulkThreshold   - a document with at least this many files is sent in
%                     zip batches (ndi.cloud.upload.zipForUpload) rather
%                     than one signed upload per file. Default 20.
%   UploadTimeout   - seconds to wait for NDI Cloud to record one
%                     document's files. Empty (default) scales with the
%                     number and size of the files.
%   CacheDir        - where local copies are kept. Default: a new folder
%                     in tempdir.
%   KeepLocalCopies - keep CACHEDIR after COMMIT (and on delete).
%                     Default false. A resumable job keeps it, so a level
%                     retained for the next one survives a restart.
%   RetrySeconds    - how long a failing cloud call (lost connection,
%                     server hiccup) is retried, with waits growing from
%                     2 s to 60 s, before it is an error. Default 1800 (30
%                     minutes). 0 retries nothing. An addDocument is never
%                     retried blindly: the dataset is asked first whether
%                     the document arrived.
%   OnUpload        - function handle called with each document once it is
%                     in the cloud (from DECLARE or COMMIT), with its series
%                     member paths still in it. ndi.job.LightsheetToCloud
%                     records them so an interrupted run can resume.
%   Api             - the cloud calls to use; see DEFAULTAPI. Tests pass
%                     a fake (ndi.test.helper.FakeCloudDataset).
%
%   Methods (the part of ndi.session that document builders use):
%     id, newdocument, database_add, database_openbinarydoc,
%     database_closebinarydoc
%   streaming:
%     declare(DOC), streamMembers(DOC, SERIES, INDICES, PATHS, RETAIN),
%     releaseMembers(DOC), replaceOnCommit(DOC)
%   and:
%     requireSubject(ID)  - error unless ID is a subject in this session
%     requireDocument(ID) - error unless ID is in the dataset or was added here
%     report = commit()   - upload the held documents
%
%   See also: ndi.fun.doc.lightsheet.fromOMEZarr,
%             ndi.fun.doc.lightsheet.fromSPIM,
%             ndi.cloud.upload.SessionWriter.listSessions,
%             ndi.cloud.upload.SessionWriter.listSubjects,
%             ndi.cloud.api.files.lookupFiles, ndi.fun.file.crc32

    properties (SetAccess = private)
        cloudDatasetId char = ''
        sessionId char = ''
        sessionReference char = ''
        cacheDir char = ''
        % Counts of what has been sent so far; COMMIT returns it too.
        report = struct('documents', 0, 'files', 0, 'bytes', 0, ...
            'resent', 0, 'documentIds', {{}})
        committed (1,1) logical = false
        % Seconds spent, so far, getting signed upload URLs, staging files
        % (move + CRC-32), sending them or waiting for a background send,
        % and checking them with the cloud. A profiler (see
        % ndi.fun.doc.lightsheet.BuildProfile) reads the change per batch.
        timing = struct('urls', 0, 'stage', 0, 'send', 0, 'verify', 0)
    end

    properties (Access = private)
        api struct
        verbose (1,1) logical = true
        bulkThreshold (1,1) double = 20
        uploadTimeout double = []
        parallelUploads (1,1) double = 4
        keepLocalCopies (1,1) logical = false
        % Documents sent in DATABASE_ADD, waiting for COMMIT, in order.
        pendingDocs = {}
        % ids added through this writer, and ids confirmed in the cloud.
        knownIds
        cloudIds
        % 'docid|filename' -> uid, for every file sent or declared.
        fileUids
        % STREAMING (see declare / streamMembers). Batches sent but not
        % yet checked against the cloud, oldest first; the series member
        % uids each declared document promises (docid -> cellstr); the
        % local copies kept for a later level to read (docid -> cellstr
        % of paths); and documents to replace in the cloud at COMMIT.
        outstanding = {}
        onUpload = []
        declaredUids
        retainedPaths
        replaceAtCommit = {}
    end

    methods
        function obj = SessionWriter(cloudDatasetId, sessionId, options)
            arguments
                cloudDatasetId (1,:) char {mustBeNonempty}
                sessionId (1,:) char {mustBeNonempty}
                options.Verbose (1,1) logical = true
                options.BulkThreshold (1,1) double {mustBePositive} = 20
                options.UploadTimeout double {mustBeScalarOrEmpty, mustBePositive} = []
                options.ParallelUploads (1,1) double {mustBeInteger, mustBePositive} = 4
                options.CacheDir (1,:) char = ''
                options.KeepLocalCopies (1,1) logical = false
                options.RetrySeconds (1,1) double {mustBeNonnegative} = 1800
                options.OnUpload = []
                options.Api = []
            end
            api = options.Api;
            if isempty(api)
                api = ndi.cloud.upload.SessionWriter.defaultApi();
            end
            api = addRetries(api, options.RetrySeconds);
            obj.api = api;
            obj.onUpload = options.OnUpload;
            obj.cloudDatasetId = cloudDatasetId;
            obj.verbose = options.Verbose;
            obj.bulkThreshold = options.BulkThreshold;
            obj.uploadTimeout = options.UploadTimeout;
            obj.parallelUploads = options.ParallelUploads;
            obj.keepLocalCopies = options.KeepLocalCopies;
            obj.knownIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            obj.cloudIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            obj.fileUids = containers.Map('KeyType', 'char', 'ValueType', 'char');
            obj.declaredUids = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.retainedPaths = containers.Map('KeyType', 'char', 'ValueType', 'any');

            sessions = ndi.cloud.upload.SessionWriter.listSessions( ...
                cloudDatasetId, 'Api', api);
            match = find(strcmp({sessions.session_id}, sessionId), 1);
            if isempty(match)
                if isempty(sessions)
                    have = 'It has no sessions.';
                else
                    have = ['Its sessions: ' strjoin(arrayfun(@(s) ...
                        sprintf('%s (%s)', s.session_reference, s.session_id), ...
                        sessions, 'UniformOutput', false), ', ') '.'];
                end
                error('NDI:cloud:SessionWriter:noSuchSession', ...
                    ['%s is not a session of cloud dataset %s. Documents ' ...
                     'go to a session in a dataset, not to the dataset ' ...
                     'itself. %s'], sessionId, cloudDatasetId, have);
            end
            obj.sessionId = sessionId;
            obj.sessionReference = sessions(match).session_reference;

            obj.cacheDir = options.CacheDir;
            if isempty(obj.cacheDir)
                obj.cacheDir = fullfile(tempdir, ...
                    ['ndi-cloud-session-' char(did.ido.unique_id())]);
            end
            if ~isfolder(obj.cacheDir)
                mkdir(obj.cacheDir);
            end
        end

        function delete(obj)
            % A send still running reads files about to be deleted: stop it.
            for k = 1:numel(obj.outstanding)
                stopSender(obj.outstanding{k});
            end
            obj.outstanding = {};
            if ~obj.keepLocalCopies && ~isempty(obj.cacheDir) && isfolder(obj.cacheDir)
                try
                    rmdir(obj.cacheDir, 's');
                catch
                end
            end
        end

        function i = id(obj)
        % ID - the id of the cloud session documents are added to
            i = obj.sessionId;
        end

        function doc = newdocument(obj, document_type, varargin)
        % NEWDOCUMENT - a new ndi.document in this session (as ndi.session/newdocument)
            if nargin < 2
                document_type = 'base';
            end
            inputs = cat(2, varargin, {'base.session_id', obj.sessionId});
            doc = ndi.document(document_type, inputs);
        end

        function requireSubject(obj, subjectId)
        % REQUIRESUBJECT - error unless SUBJECTID is a subject document in this session
            subjectId = char(subjectId);
            q = ndi.query('base.id', 'exact_string', subjectId) & ...
                ndi.query('', 'isa', 'subject');
            docs = obj.api.findDocuments(obj.cloudDatasetId, q);
            if isempty(docs)
                error('NDI:cloud:SessionWriter:noSubject', ...
                    ['There is no subject %s in cloud dataset %s. Add the ' ...
                     'subject to session %s first.'], subjectId, ...
                    obj.cloudDatasetId, obj.sessionReference);
            end
            where = char(docs{1}.base.session_id);
            if ~strcmp(where, obj.sessionId)
                error('NDI:cloud:SessionWriter:subjectInOtherSession', ...
                    ['Subject %s belongs to session %s, not to session %s ' ...
                     '(%s). A document must depend on a subject of its own ' ...
                     'session.'], subjectId, where, obj.sessionReference, ...
                    obj.sessionId);
            end
            obj.cloudIds(subjectId) = true;
        end

        function requireDocument(obj, docId)
        % REQUIREDOCUMENT - error unless DOCID was added here or is in the cloud dataset
            docId = char(docId);
            if isKey(obj.knownIds, docId) || isKey(obj.cloudIds, docId)
                return
            end
            docs = obj.api.findDocuments(obj.cloudDatasetId, ...
                ndi.query('base.id', 'exact_string', docId));
            if isempty(docs)
                error('NDI:cloud:SessionWriter:missingDependency', ...
                    'Document %s is not in cloud dataset %s.', docId, ...
                    obj.cloudDatasetId);
            end
            obj.cloudIds(docId) = true;
        end

        function obj = database_add(obj, document)
        % DATABASE_ADD - send a document's files now, and hold the document for COMMIT
        %
        %   Like ndi.session/database_add, a document with no session id
        %   is given this one and a document from another session is
        %   refused. DOCUMENT may be a cell array.
            if obj.committed
                error('NDI:cloud:SessionWriter:alreadyCommitted', ...
                    'This writer has already committed; make a new one.');
            end
            if ~iscell(document)
                document = {document};
            end
            for k = 1:numel(document)
                obj.addOne(document{k});
            end
        end

        function f = database_openbinarydoc(obj, document, filename)
        % DATABASE_OPENBINARYDOC - the local copy of a file this writer sent
        %
        %   Returns a struct with field FULLPATHFILENAME, which is what the
        %   lightsheet builders read. A file no longer cached is
        %   downloaded first.
            if isa(document, 'ndi.document')
                docId = document.id();
            else
                docId = char(document);
            end
            key = [docId '|' char(filename)];
            if ~isKey(obj.fileUids, key)
                error('NDI:cloud:SessionWriter:noSuchFile', ...
                    'No file %s was added through this writer for document %s.', ...
                    char(filename), docId);
            end
            uid = obj.fileUids(key);
            p = fullfile(obj.cacheDir, uid);
            if ~isfile(p)
                [ok, msg] = obj.api.downloadFile(obj.cloudDatasetId, uid, p);
                if ~ok || ~isfile(p)
                    error('NDI:cloud:SessionWriter:downloadFailed', ...
                        'Could not download %s (%s) from the cloud: %s', ...
                        char(filename), uid, char(msg));
                end
            end
            f = struct('fullpathfilename', p);
        end

        function database_closebinarydoc(~, ~)
        % DATABASE_CLOSEBINARYDOC - nothing to close; see DATABASE_OPENBINARYDOC
        end

        function r = commit(obj)
        % COMMIT - finish: check what is outstanding, then upload the held documents
        %
        %   Batches still being checked are checked; the documents held
        %   by DATABASE_ADD are uploaded in the order added, as the JSON a
        %   local session would store (series member paths stripped),
        %   which is what uploadDataset sends. Every series member a
        %   DECLAREd document promises must then be in the cloud, or this
        %   is an error naming how many are missing. Last, documents
        %   handed to REPLACEATCOMMIT replace their earlier versions.
            if obj.committed
                r = obj.report;
                return
            end
            obj.verifyOutstanding();
            obj.flushPending();
            obj.checkDeclaredMembers();
            for k = 1:numel(obj.replaceAtCommit)
                doc = obj.replaceAtCommit{k};
                props = did.document.stripSeriesIngestLocations(doc.document_properties);
                [ok, answer] = obj.api.updateDocument(obj.cloudDatasetId, doc.id(), ...
                    did.datastructures.jsonencodenan(props));
                if ~ok
                    error('NDI:cloud:SessionWriter:updateFailed', ...
                        ['Every file is in cloud dataset %s, but document %s ' ...
                         'could not be updated to its final version: %s'], ...
                        obj.cloudDatasetId, doc.id(), describe(answer));
                end
            end
            obj.replaceAtCommit = {};
            obj.committed = true;
            obj.say('Done: %d document(s), %d file(s), %.1f MB.', ...
                obj.report.documents, obj.report.files, obj.report.bytes / 1e6);
            if ~obj.keepLocalCopies && isfolder(obj.cacheDir)
                rmdir(obj.cacheDir, 's');
            end
            r = obj.report;
        end

        % -------------------------------------------------------------
        % STREAMING. A document whose file series is built over hours is
        % DECLAREd first -- uploaded at once, with every member's uid
        % already in its manifest -- and its members are then sent in
        % batches as they are made (STREAMMEMBERS), each batch checked
        % against the cloud's CRC-32 and its local copies deleted unless
        % a later step still reads them (RELEASEMEMBERS frees those).
        % Nothing in the cloud is ever unreferenced, and the disk holds
        % only what is in flight plus what is retained.
        % -------------------------------------------------------------

        function declare(obj, doc)
        % DECLARE - upload a document now, before its series members exist
        %
        %   DOC's ordinary files (a series' manifest among them) are sent
        %   and checked first, then DOC itself. Documents still held by
        %   DATABASE_ADD go up before it, in order, since DOC may depend
        %   on them. Its series members are recorded as promised; send
        %   them with STREAMMEMBERS. COMMIT checks that all arrived.
            if obj.committed
                error('NDI:cloud:SessionWriter:alreadyCommitted', ...
                    'This writer has already committed; make a new one.');
            end
            doc = obj.ownSession(doc);
            obj.checkDependencies(doc);
            obj.flushPending();
            entries = ndi.cloud.upload.SessionWriter.filesOf(doc, false);
            if ~isempty(entries)
                obj.verifyBatch(obj.stageAndSend(doc, entries, true));
            end
            obj.registerSeries(doc);
            obj.addNow(doc, 1, 1);
            obj.knownIds(doc.id()) = true;
        end

        function adopt(obj, doc)
        % ADOPT - take on a document an earlier run already put in the cloud
        %
        %   For resuming: DOC (as it was declared or added, series member
        %   uids included) is treated as uploaded -- a dependency other
        %   documents may name, and, if it has a series, a DECLAREd
        %   document whose members STREAMMEMBERS may send and COMMIT will
        %   check. Nothing is uploaded.
            doc = obj.ownSession(doc);
            obj.registerSeries(doc);
            obj.knownIds(doc.id()) = true;
        end

        function idx = missingMembers(obj, doc, seriesName)
        % MISSINGMEMBERS - the members of a declared series the cloud does not have yet
        %
        %   IDX = MISSINGMEMBERS(W, DOC, SERIESNAME) returns the one-based
        %   member indices whose uid the dataset does not report as
        %   uploaded. A resumed run builds only these.
            idx = [];
            si = seriesInfoOf(doc);
            k = find(strcmp({si.name}, seriesName), 1);
            if isempty(k), return; end
            locs = si(k).ingest_locations;
            if isempty(locs), return; end
            uids = arrayfun(@(L) char(L.uid), locs, 'UniformOutput', false);
            [ok, answer] = obj.api.lookupFiles(obj.cloudDatasetId, uids);
            if ~ok
                error('NDI:cloud:SessionWriter:lookupFailed', ...
                    'Could not look up files in cloud dataset %s: %s', ...
                    obj.cloudDatasetId, describe(answer));
            end
            rows = answer.files;
            have = {};
            if ~isempty(rows)
                have = cellfun(@char, {rows([rows.uploaded]).uid}, 'UniformOutput', false);
            end
            idx = [locs(~ismember(uids, have)).index];
        end

        function streamMembers(obj, doc, seriesName, indices, paths, retain)
        % STREAMMEMBERS - send some members of a DECLAREd document's series
        %
        %   STREAMMEMBERS(W, DOC, SERIESNAME, INDICES, PATHS, RETAIN)
        %
        %   PATHS{i} holds member INDICES(i) (one-based) of SERIESNAME; it
        %   is moved into the cache and sent under the uid DOC's manifest
        %   gave that member. The batch is checked against the cloud at
        %   the NEXT call (or at RELEASEMEMBERS / COMMIT), so the server
        %   records one batch while the next is being built. Once checked,
        %   the local copies are deleted, unless RETAIN, in which case
        %   they stay readable through DATABASE_OPENBINARYDOC until
        %   RELEASEMEMBERS.
            arguments
                obj
                doc
                seriesName (1,:) char
                indices double
                paths cell
                retain (1,1) logical = false
            end
            n = numel(indices);
            if n == 0
                % Nothing new: just check what is outstanding.
                obj.verifyOutstanding();
                return
            end
            entries = struct('name', cell(1, n), 'uid', cell(1, n), ...
                'path', cell(1, n), 'deleteOriginal', cell(1, n));
            for i = 1:n
                name = sprintf('%s_%d', seriesName, indices(i));
                key = [doc.id() '|' name];
                if ~isKey(obj.fileUids, key)
                    error('NDI:cloud:SessionWriter:notDeclared', ...
                        ['Member %s of document %s was not declared. DECLARE ' ...
                         'the document, with its whole series, first.'], name, doc.id());
                end
                entries(i) = struct('name', name, 'uid', obj.fileUids(key), ...
                    'path', char(paths{i}), 'deleteOriginal', true);
            end
            obj.outstanding{end+1} = obj.stageAndSend(doc, entries, retain);
            while numel(obj.outstanding) > 1
                batch = obj.outstanding{1};
                obj.outstanding(1) = [];
                obj.verifyBatch(batch);
            end
        end

        function releaseMembers(obj, doc)
        % RELEASEMEMBERS - delete the local copies STREAMMEMBERS kept for DOC
            obj.verifyOutstanding();
            id = doc.id();
            if ~isKey(obj.retainedPaths, id), return; end
            kept = obj.retainedPaths(id);
            for i = 1:numel(kept)
                if isfile(kept{i}), delete(kept{i}); end
            end
            remove(obj.retainedPaths, id);
        end

        function replaceOnCommit(obj, doc)
        % REPLACEONCOMMIT - at COMMIT, replace the cloud copy of DOC with this version
        %
        %   For a document uploaded early that should change once the
        %   work is done -- a pyramid labelled "(uploading)" until every
        %   chunk is in.
            obj.replaceAtCommit{end+1} = doc;
        end
    end

    methods (Access = private)
        function addOne(obj, doc)
            doc = obj.ownSession(doc);
            obj.checkDependencies(doc);

            entries = ndi.cloud.upload.SessionWriter.filesOf(doc, true);
            if ~isempty(entries)
                % Kept locally until COMMIT: a builder may read them back.
                obj.verifyBatch(obj.stageAndSend(doc, entries, true));
            end

            obj.pendingDocs{end+1} = doc;
            obj.knownIds(doc.id()) = true;
        end

        function doc = ownSession(obj, doc)
        % As ndi.session/database_add: no session id gets this one,
        % another session's is refused.
            sid = char(doc.document_properties.base.session_id);
            if isempty(sid) || strcmp(sid, ndi.session.empty_id())
                doc = doc.set_session_id(obj.sessionId);
            elseif ~strcmp(sid, obj.sessionId)
                error('NDI:cloud:SessionWriter:wrongSession', ...
                    'Document %s belongs to session %s, not to %s.', ...
                    doc.id(), sid, obj.sessionId);
            end
        end

        function registerSeries(obj, doc)
        % Record a document's series member uids as promised (DECLARE, ADOPT).
            promised = {};
            si = seriesInfoOf(doc);
            for s = 1:numel(si)
                locs = si(s).ingest_locations;
                for k = 1:numel(locs)
                    uid = char(locs(k).uid);
                    obj.fileUids(sprintf('%s|%s_%d', doc.id(), char(si(s).name), ...
                        locs(k).index)) = uid;
                    promised{end+1} = uid; %#ok<AGROW>
                end
            end
            obj.declaredUids(doc.id()) = promised;
        end

        function addNow(obj, doc, k, n)
        % Upload one document's JSON (series member paths stripped).
            props = did.document.stripSeriesIngestLocations(doc.document_properties);
            [ok, answer] = obj.api.addDocument(obj.cloudDatasetId, ...
                did.datastructures.jsonencodenan(props));
            if ~ok
                error('NDI:cloud:SessionWriter:addDocumentFailed', ...
                    ['Could not add document %s (%s) to cloud dataset ' ...
                     '%s: %s. %d of %d documents were added before it.'], ...
                    doc.id(), doc.document_properties.document_class.class_name, ...
                    obj.cloudDatasetId, describe(answer), k - 1, n);
            end
            obj.report.documents = obj.report.documents + 1;
            obj.report.documentIds{end+1} = doc.id();
            if ~isempty(obj.onUpload)
                obj.onUpload(doc);
            end
        end

        function flushPending(obj)
        % Upload the documents DATABASE_ADD held, in order.
            n = numel(obj.pendingDocs);
            if n == 0, return; end
            obj.say('Adding %d document(s) to session %s of cloud dataset %s ...', ...
                n, obj.sessionReference, obj.cloudDatasetId);
            for k = 1:n
                obj.addNow(obj.pendingDocs{k}, k, n);
            end
            obj.pendingDocs = {};
        end

        function verifyOutstanding(obj)
            while ~isempty(obj.outstanding)
                batch = obj.outstanding{1};
                obj.outstanding(1) = [];
                obj.verifyBatch(batch);
            end
        end

        function checkDeclaredMembers(obj)
        % Every member a declared document promises must be in the cloud.
            ids = keys(obj.declaredUids);
            for k = 1:numel(ids)
                uids = obj.declaredUids(ids{k});
                if isempty(uids), continue; end
                [ok, answer] = obj.api.lookupFiles(obj.cloudDatasetId, uids);
                if ~ok
                    error('NDI:cloud:SessionWriter:lookupFailed', ...
                        'Could not look up files in cloud dataset %s: %s', ...
                        obj.cloudDatasetId, describe(answer));
                end
                rows = answer.files;
                have = {};
                if ~isempty(rows)
                    have = cellfun(@char, {rows([rows.uploaded]).uid}, 'UniformOutput', false);
                end
                nMissing = numel(setdiff(uids, have));
                if nMissing > 0
                    error('NDI:cloud:SessionWriter:membersMissing', ...
                        ['%d of the %d series members document %s declares are ' ...
                         'not in cloud dataset %s.'], nMissing, numel(uids), ...
                        ids{k}, obj.cloudDatasetId);
                end
            end
        end

        function checkDependencies(obj, doc)
            props = doc.document_properties;
            if ~isfield(props, 'depends_on') || isempty(props.depends_on)
                return
            end
            deps = props.depends_on;
            for i = 1:numel(deps)
                value = char(deps(i).value);
                if isempty(value) || isKey(obj.knownIds, value) || isKey(obj.cloudIds, value)
                    continue
                end
                if strcmp(deps(i).name, 'subject_id')
                    obj.requireSubject(value);
                else
                    obj.requireDocument(value);
                end
            end
        end

        function batch = stageAndSend(obj, doc, entries, retain)
        % STAGEANDSEND - move ENTRIES into the cache under their uids and send them
        %
        %   Zip batches for many files, one CRC-32-signed upload each for
        %   few. Returns what VERIFYBATCH needs; nothing is checked here.
            n = numel(entries);
            paths = cell(1, n);
            bytes = zeros(1, n);
            crcs = cell(1, n);
            t0 = tic;
            for i = 1:n
                paths{i} = obj.stage(entries(i));
                d = dir(paths{i});
                bytes(i) = d.bytes;
                crcs{i} = ndi.fun.file.crc32(paths{i});
            end
            obj.timing.stage = obj.timing.stage + toc(t0);
            uids = {entries.uid};
            label = sprintf('%s %s', ...
                doc.document_properties.document_class.class_name, doc.id());
            sender = [];
            if n >= obj.bulkThreshold
                obj.say('Sending %d file(s), %.1f MB, for %s ...', n, sum(bytes) / 1e6, label);
                t0 = tic;
                [ok, msg] = obj.api.uploadFileBatch(obj.cloudDatasetId, paths, bytes);
                obj.timing.send = obj.timing.send + toc(t0);
                if ~ok
                    % Not fatal yet: whatever did not arrive is sent
                    % again one by one when the batch is checked.
                    obj.say('A zip batch failed (%s); checking what arrived.', char(msg));
                end
            else
                sender = obj.startBackgroundSend(uids, paths, crcs);
                if isempty(sender)
                    obj.say('Sending %d file(s), %.1f MB, for %s ...', n, sum(bytes) / 1e6, label);
                    t0 = tic;
                    for i = 1:n
                        [ok, msg] = obj.api.uploadSingleFile(obj.cloudDatasetId, uids{i}, paths{i});
                        if ~ok
                            obj.say('Sending %s failed (%s); will retry.', uids{i}, char(msg));
                        end
                    end
                    obj.timing.send = obj.timing.send + toc(t0);
                else
                    obj.say('Sending %d file(s), %.1f MB, for %s (%d at a time, in the background) ...', ...
                        n, sum(bytes) / 1e6, label, obj.parallelUploads);
                end
            end
            batch = struct('docId', doc.id(), 'label', label, ...
                'names', {{entries.name}}, 'uids', {uids}, 'paths', {paths}, ...
                'bytes', bytes, 'crcs', {crcs}, 'retain', retain);
            batch.sender = sender;
        end

        function sender = startBackgroundSend(obj, uids, paths, crcs)
        % STARTBACKGROUNDSEND - start a background send of a batch, or []
        %
        %   [] when the API cannot (no curl new enough, a fake without it,
        %   ParallelUploads 1) or a signed upload URL could not be had; the
        %   caller then sends the files one by one.
            sender = [];
            if obj.parallelUploads < 2 || ~isfield(obj.api, 'startSend') || ...
                    ~isfield(obj.api, 'uploadURL')
                return
            end
            n = numel(uids);
            urls = cell(1, n);
            t0 = tic;
            stopwatch = onCleanup(@() obj.addTime('urls', toc(t0)));
            for i = 1:n
                [ok, url] = obj.api.uploadURL(obj.cloudDatasetId, uids{i}, crcs{i});
                if ~ok
                    obj.say('Could not get an upload URL for %s (%s); sending one by one.', ...
                        uids{i}, describe(url));
                    return
                end
                urls{i} = char(url);
            end
            clear stopwatch
            try
                sender = obj.api.startSend(urls, paths, crcs, uids, ...
                    fullfile(obj.cacheDir, 'sending'), obj.parallelUploads);
            catch ME
                obj.say('Could not start a background send (%s); sending one by one.', ME.message);
                sender = [];
            end
        end

        function verifyBatch(obj, batch)
        % VERIFYBATCH - check a sent batch against the cloud, resend what is wrong
        %
        %   A file that is missing or whose CRC-32 (or size) differs is
        %   sent again on its own; one still wrong after that is an error.
        %   Then the batch's local copies are deleted unless it is
        %   retained.
            uids = batch.uids; paths = batch.paths;
            bytes = batch.bytes; crcs = batch.crcs;
            n = numel(uids);
            timeout = obj.uploadTimeout;
            if isempty(timeout)
                timeout = max(120, 30 + 0.05 * n + sum(bytes) / 5e6);
            end
            if isfield(batch, 'sender') && ~isempty(batch.sender)
                % Sent in the background: let it finish first. curl ends a
                % stalled transfer itself; this cap (100 kB/s) is a backstop.
                t0 = tic;
                [ok, msg] = batch.sender.wait(max(600, sum(bytes) / 1e5));
                obj.timing.send = obj.timing.send + toc(t0);
                stopSender(batch);
                if ~ok
                    obj.say('The background send of %s reported a problem (%s); checking what arrived.', ...
                        batch.label, char(msg));
                end
            end
            t0 = tic;
            stopwatch = onCleanup(@() obj.addTime('verify', toc(t0)));
            bad = obj.unverified(uids, bytes, crcs, timeout);

            if any(bad)
                obj.say('%d of %d file(s) missing or different in the cloud; sending them again.', ...
                    nnz(bad), n);
                for i = find(bad)
                    [ok, msg] = obj.api.uploadSingleFile(obj.cloudDatasetId, uids{i}, paths{i});
                    if ~ok
                        obj.say('Sending %s again failed (%s).', uids{i}, char(msg));
                    end
                end
                obj.report.resent = obj.report.resent + nnz(bad);
                stillBad = bad;
                stillBad(bad) = obj.unverified(uids(bad), bytes(bad), crcs(bad), timeout);
                if any(stillBad)
                    first = find(stillBad, 1);
                    error('NDI:cloud:SessionWriter:uploadNotVerified', ...
                        ['%d file(s) of %s could not be verified in cloud ' ...
                         'dataset %s after sending them twice (first: %s, ' ...
                         'local %s).'], ...
                        nnz(stillBad), batch.label, obj.cloudDatasetId, ...
                        uids{first}, paths{first});
                end
            end

            for i = 1:n
                obj.fileUids([batch.docId '|' batch.names{i}]) = uids{i};
            end
            obj.report.files = obj.report.files + n;
            obj.report.bytes = obj.report.bytes + sum(bytes);

            if batch.retain
                kept = {};
                if isKey(obj.retainedPaths, batch.docId)
                    kept = obj.retainedPaths(batch.docId);
                end
                obj.retainedPaths(batch.docId) = [kept paths];
            else
                for i = 1:n
                    if isfile(paths{i}), delete(paths{i}); end
                end
            end
        end

        function addTime(obj, what, seconds)
            if isvalid(obj)
                obj.timing.(what) = obj.timing.(what) + seconds;
            end
        end

        function bad = unverified(obj, uids, bytes, crcs, timeout)
        % UNVERIFIED - true for each uid the cloud lacks or holds different bytes for
            obj.api.waitForFileUpload(obj.cloudDatasetId, uids, timeout);
            [ok, answer] = obj.api.lookupFiles(obj.cloudDatasetId, uids);
            if ~ok
                error('NDI:cloud:SessionWriter:lookupFailed', ...
                    'Could not look up uploaded files in cloud dataset %s: %s', ...
                    obj.cloudDatasetId, describe(answer));
            end
            rows = answer.files;
            rowUids = cellfun(@char, {rows.uid}, 'UniformOutput', false);
            bad = true(1, numel(uids));
            for i = 1:numel(uids)
                j = find(strcmp(rowUids, uids{i}), 1);
                if isempty(j) || ~rows(j).uploaded
                    continue
                end
                cloudCrc = char(rows(j).crc32);
                if isempty(cloudCrc)
                    bad(i) = double(rows(j).size) ~= bytes(i);
                else
                    bad(i) = ~strcmp(cloudCrc, crcs{i});
                end
            end
        end

        function p = stage(obj, entry)
        % STAGE - put one file into the cache under its uid
            p = fullfile(obj.cacheDir, entry.uid);
            if isfile(p)
                return
            end
            if ~isfile(entry.path)
                error('NDI:cloud:SessionWriter:fileNotFound', ...
                    'File %s (%s) is not at %s.', entry.name, entry.uid, entry.path);
            end
            if entry.deleteOriginal
                [ok, msg] = movefile(entry.path, p, 'f');
            else
                [ok, msg] = copyfile(entry.path, p, 'f');
            end
            if ~ok
                error('NDI:cloud:SessionWriter:stageFailed', ...
                    'Could not copy %s to %s: %s', entry.path, p, msg);
            end
        end

        function say(obj, varargin)
            if obj.verbose
                fprintf(['[SessionWriter] ' varargin{1} '\n'], varargin{2:end});
            end
        end
    end

    methods (Static)
        function sessions = listSessions(cloudDatasetId, options)
        % LISTSESSIONS - the sessions in a cloud dataset
        %
        %   SESSIONS = ndi.cloud.upload.SessionWriter.listSessions(CLOUDDATASETID)
        %
        %   Returns a struct array with fields session_id and
        %   session_reference, from the dataset's session_in_a_dataset
        %   documents (and an older dataset's dataset_session_info).
            arguments
                cloudDatasetId (1,:) char
                options.Api = []
            end
            api = options.Api;
            if isempty(api)
                api = ndi.cloud.upload.SessionWriter.defaultApi();
            end
            sessions = struct('session_id', {}, 'session_reference', {});
            docs = api.findDocuments(cloudDatasetId, ...
                ndi.query('', 'isa', 'session_in_a_dataset'));
            for i = 1:numel(docs)
                s = docs{i}.session_in_a_dataset;
                sessions(end+1) = struct('session_id', char(s.session_id), ...
                    'session_reference', char(s.session_reference)); %#ok<AGROW>
            end
            docs = api.findDocuments(cloudDatasetId, ...
                ndi.query('', 'isa', 'dataset_session_info'));
            for i = 1:numel(docs)
                info = docs{i}.dataset_session_info.dataset_session_info;
                if iscell(info), info = [info{:}]; end
                for k = 1:numel(info)
                    sessions(end+1) = struct('session_id', char(info(k).session_id), ...
                        'session_reference', char(info(k).session_reference)); %#ok<AGROW>
                end
            end
            [~, keep] = unique({sessions.session_id}, 'stable');
            sessions = sessions(keep);
        end

        function subjects = listSubjects(cloudDatasetId, sessionId, options)
        % LISTSUBJECTS - the subjects in one session of a cloud dataset
        %
        %   SUBJECTS = ndi.cloud.upload.SessionWriter.listSubjects(CLOUDDATASETID, SESSIONID)
        %
        %   Returns a struct array with fields id and local_identifier.
            arguments
                cloudDatasetId (1,:) char
                sessionId (1,:) char
                options.Api = []
            end
            api = options.Api;
            if isempty(api)
                api = ndi.cloud.upload.SessionWriter.defaultApi();
            end
            q = ndi.query('', 'isa', 'subject') & ...
                ndi.query('base.session_id', 'exact_string', sessionId);
            docs = api.findDocuments(cloudDatasetId, q);
            subjects = struct('id', {}, 'local_identifier', {});
            for i = 1:numel(docs)
                subjects(end+1) = struct('id', char(docs{i}.base.id), ...
                    'local_identifier', char(docs{i}.subject.local_identifier)); %#ok<AGROW>
            end
        end

        function api = defaultApi()
        % DEFAULTAPI - the NDI Cloud calls a SessionWriter makes
        %
        %   A struct of function handles:
        %     findDocuments(datasetId, query)      -> cell of document property structs
        %     addDocument(datasetId, json)         -> [ok, answer]
        %     uploadSingleFile(datasetId, uid, path)  -> [ok, msg]  (CRC-32 signed)
        %     uploadFileBatch(datasetId, paths, bytes) -> [ok, msg] (zip batches)
        %     uploadURL(datasetId, uid, crc)       -> [ok, url]  (signed for CRC)
        %     startSend(urls, paths, crcs, uids, folder, n) -> a sender with
        %         [ok, msg] = wait(timeout), or [] if this computer cannot
        %         (see ndi.cloud.upload.CurlSender); optional
        %     waitForFileUpload(datasetId, uids, timeout) -> [ok, answer]
        %     lookupFiles(datasetId, uids)         -> [ok, answer]
        %     downloadFile(datasetId, uid, path)   -> [ok, msg]
        %     updateDocument(datasetId, ndiId, json) -> [ok, answer]
            api = struct( ...
                'findDocuments', @findCloudDocuments, ...
                'addDocument', @(d, json) ndi.cloud.api.documents.addDocument(d, json), ...
                'uploadSingleFile', @(d, uid, p) ndi.cloud.uploadSingleFile(d, uid, p, ...
                    'checksum', true, 'waitForUpload', false), ...
                'uploadFileBatch', @uploadBatch, ...
                'uploadURL', @uploadURL, ...
                'startSend', @startCurlSend, ...
                'waitForFileUpload', @(d, uids, t) ndi.cloud.api.files.waitForFileUpload( ...
                    d, string(uids), 'timeout', t), ...
                'lookupFiles', @(d, uids) ndi.cloud.api.files.lookupFiles(d, string(uids)), ...
                'downloadFile', @downloadOne, ...
                'updateDocument', @updateByNdiId);
        end
    end

    methods (Static, Access = private)
        function entries = filesOf(doc, includeMembers)
        % FILESOF - the files (and, if INCLUDEMEMBERS, series members) a
        % document carries for ingestion
        %
        %   Collected into cells and made a struct array once: a pyramid
        %   level has tens of thousands of members.
            names = {}; uids = {}; paths = {}; dels = {};
            props = doc.document_properties;
            if isfield(props, 'files') && isstruct(props.files)
                if isfield(props.files, 'file_info')
                    fi = props.files.file_info;
                    for i = 1:numel(fi)
                        L = reshape(fi(i).locations, 1, []);
                        take = arrayfun(@isIngestedFile, L);
                        names = [names repmat({char(fi(i).name)}, 1, nnz(take))]; %#ok<AGROW>
                        uids  = [uids  cellfun(@char, {L(take).uid}, 'UniformOutput', false)]; %#ok<AGROW>
                        paths = [paths cellfun(@char, {L(take).location}, 'UniformOutput', false)]; %#ok<AGROW>
                        dels  = [dels  arrayfun(@(x) logical(x.delete_original), L(take), 'UniformOutput', false)]; %#ok<AGROW>
                    end
                end
                if includeMembers && isfield(props.files, 'series_info')
                    si = props.files.series_info;
                    for s = 1:numel(si)
                        L = [];
                        if isfield(si(s), 'ingest_locations')
                            L = si(s).ingest_locations;
                        end
                        if isempty(L)
                            if isfield(si(s), 'n_present') && ~isempty(si(s).n_present) ...
                                    && si(s).n_present > 0
                                error('NDI:cloud:SessionWriter:membersNotLocatable', ...
                                    ['Document %s declares %d members of file series ' ...
                                     '%s but records where none of them are.'], ...
                                    doc.id(), si(s).n_present, char(si(s).name));
                            end
                            continue
                        end
                        L = reshape(L, 1, []);
                        take = arrayfun(@isIngestedFile, L);
                        stem = char(si(s).name);
                        names = [names arrayfun(@(x) sprintf('%s_%d', stem, x.index), ...
                            L(take), 'UniformOutput', false)]; %#ok<AGROW>
                        uids  = [uids  cellfun(@char, {L(take).uid}, 'UniformOutput', false)]; %#ok<AGROW>
                        paths = [paths cellfun(@char, {L(take).location}, 'UniformOutput', false)]; %#ok<AGROW>
                        dels  = [dels  arrayfun(@(x) logical(x.delete_original), L(take), 'UniformOutput', false)]; %#ok<AGROW>
                    end
                end
            end
            entries = struct('name', names, 'uid', uids, 'path', paths, ...
                'deleteOriginal', dels);
        end
    end
end

function docs = findCloudDocuments(cloudDatasetId, q)
% The full properties of the documents in a dataset that match Q:
% ndiqueryAll finds them, bulkFetch (500 at a time) reads them.
    docs = {};
    [ok, hits] = ndi.cloud.api.documents.ndiqueryAll(string(cloudDatasetId), q);
    if ~ok
        error('NDI:cloud:SessionWriter:queryFailed', ...
            'Could not search cloud dataset %s: %s', cloudDatasetId, describe(hits));
    end
    if isempty(hits)
        return
    end
    if iscell(hits), hits = [hits{:}]; end
    ids = string({hits.id});
    for first = 1:500:numel(ids)
        batch = ids(first:min(first + 499, numel(ids)));
        [ok, fetched] = ndi.cloud.api.documents.bulkFetch(string(cloudDatasetId), batch);
        if ~ok
            error('NDI:cloud:SessionWriter:fetchFailed', ...
                'Could not read documents from cloud dataset %s: %s', ...
                cloudDatasetId, describe(fetched));
        end
        if isstruct(fetched), fetched = num2cell(fetched); end
        for i = 1:numel(fetched)
            docs{end+1} = fetched{i}.data; %#ok<AGROW>
        end
    end
end

function [ok, msg] = uploadBatch(cloudDatasetId, paths, bytes)
% Zip batches through the same path uploadDataset uses. The files are
% named by uid already, which is how the server files them.
    manifest = struct('file_path', paths, 'bytes', num2cell(bytes), ...
        'is_uploaded', false);
    [ok, msg] = ndi.cloud.upload.zipForUpload(struct('path', tempdir), ...
        manifest, sum(bytes) / 1e3, char(cloudDatasetId), ...
        'Verbose', false, 'DebugLog', false);
    ok = logical(ok);
end

function [ok, url] = uploadURL(cloudDatasetId, uid, crc)
    [ok, url] = ndi.cloud.api.files.getFileUploadURL(cloudDatasetId, uid, ...
        'checksumCRC32', string(crc));
end

function sender = startCurlSend(urls, paths, crcs, uids, folder, n)
    sender = [];
    if ndi.cloud.upload.CurlSender.supported()
        sender = ndi.cloud.upload.CurlSender(urls, paths, crcs, uids, folder, 'Parallel', n);
    end
end

function stopSender(batch)
% Stop and forget a batch's background send, if it has one.
    if isstruct(batch) && isfield(batch, 'sender') && ~isempty(batch.sender) ...
            && isobject(batch.sender) && isvalid(batch.sender)
        delete(batch.sender);
    end
end

function si = seriesInfoOf(doc)
    si = struct('name', {}, 'ingest_locations', {});
    p = doc.document_properties;
    if isfield(p, 'files') && isstruct(p.files) && isfield(p.files, 'series_info') ...
            && ~isempty(p.files.series_info)
        si = p.files.series_info;
    end
end

function api = addRetries(api, seconds)
% Wrap each cloud call so a failure is retried for up to SECONDS. A long
% upload meets a dropped connection or a server hiccup sooner or later;
% this rides one out instead of failing hours of work. waitForFileUpload
% is left alone: it already waits, and its timeout is an answer.
    if seconds <= 0, return; end
    raw = api;
    for name = {'uploadSingleFile', 'uploadFileBatch', 'uploadURL', 'lookupFiles', ...
            'downloadFile', 'updateDocument'}
        n = name{1};
        if isfield(raw, n)
            api.(n) = @(varargin) retryPair(raw.(n), varargin, seconds, n);
        end
    end
    api.findDocuments = @(d, q) retryOne(raw.findDocuments, {d, q}, seconds);
    api.addDocument = @(d, json) retryAdd(raw, d, json, seconds);
end

function [ok, answer] = retryPair(fn, args, seconds, name)
    t0 = tic;
    wait = 2;
    while true
        try
            [ok, answer] = fn(args{:});
        catch ME
            ok = false;
            answer = struct('message', ME.message);
        end
        if ok || toc(t0) + wait > seconds
            return
        end
        fprintf('[SessionWriter] %s failed (%s); trying again in %d s.\n', ...
            name, describe(answer), wait);
        pause(wait);
        wait = min(60, 2 * wait);
    end
end

function out = retryOne(fn, args, seconds)
    t0 = tic;
    wait = 2;
    while true
        try
            out = fn(args{:});
            return
        catch ME
            if toc(t0) + wait > seconds
                rethrow(ME);
            end
            fprintf('[SessionWriter] a cloud search failed (%s); trying again in %d s.\n', ...
                ME.message, wait);
        end
        pause(wait);
        wait = min(60, 2 * wait);
    end
end

function [ok, answer] = retryAdd(raw, d, json, seconds)
% addDocument, retried -- but only after asking whether the last try
% arrived anyway, so a lost reply never becomes a duplicate document.
    t0 = tic;
    wait = 2;
    id = '';
    try
        id = char(jsondecode(char(json)).base.id);
    catch
    end
    while true
        try
            [ok, answer] = raw.addDocument(d, json);
        catch ME
            ok = false;
            answer = struct('message', ME.message);
        end
        if ok || toc(t0) + wait > seconds
            return
        end
        fprintf('[SessionWriter] addDocument failed (%s); trying again in %d s.\n', ...
            describe(answer), wait);
        pause(wait);
        wait = min(60, 2 * wait);
        if ~isempty(id)
            try
                if ~isempty(raw.findDocuments(d, ndi.query('base.id', 'exact_string', id)))
                    ok = true;
                    answer = struct('message', 'already there');
                    return
                end
            catch
            end
        end
    end
end

function [ok, answer] = updateByNdiId(cloudDatasetId, ndiId, json)
% Replace the document whose base.id is NDIID; the API wants the cloud's id.
    [ok, hits] = ndi.cloud.api.documents.ndiqueryAll(string(cloudDatasetId), ...
        ndi.query('base.id', 'exact_string', char(ndiId)));
    if ~ok || isempty(hits)
        ok = false;
        answer = struct('message', sprintf('document %s not found', char(ndiId)));
        return
    end
    if iscell(hits), hits = [hits{:}]; end
    [ok, answer] = ndi.cloud.api.documents.updateDocument(string(cloudDatasetId), ...
        string(hits(1).id), string(json));
end

function [ok, msg] = downloadOne(cloudDatasetId, uid, destPath)
    msg = '';
    [ok, details] = ndi.cloud.api.files.getFileDetails(string(cloudDatasetId), string(uid));
    if ~ok
        msg = describe(details);
        return
    end
    [ok, answer] = ndi.cloud.api.files.getFile(string(details.downloadUrl), string(destPath));
    if ~ok
        msg = describe(answer);
    end
end

function tf = isIngestedFile(L)
% A location whose bytes a local session would copy in: those are the
% ones to send. A URL reference stays a reference.
    tf = logical(L.ingest) && strcmpi(strtrim(char(L.location_type)), 'file');
end

function s = describe(answer)
    if isstruct(answer) && isfield(answer, 'message')
        s = char(string(answer.message));
    elseif ischar(answer) || isstring(answer)
        s = char(answer);
    else
        try
            s = jsonencode(answer);
        catch
            s = class(answer);
        end
    end
end
