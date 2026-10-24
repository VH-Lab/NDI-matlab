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
%   LOCAL COPIES. Each file is moved (or copied, when its document says
%   not to delete the original) into CACHEDIR before it is sent, and kept
%   there until COMMIT, so a builder can read back what it wrote earlier
%   (fromSPIM builds each coarser level from the one before) without a
%   download. Plan for as much free disk as the files take; a local
%   session would keep them for good. A file no longer cached is
%   downloaded on demand.
%
%   Optional Name-Value Arguments:
%   Verbose         - print progress lines. Default true.
%   BulkThreshold   - a document with at least this many files is sent in
%                     zip batches (ndi.cloud.upload.zipForUpload) rather
%                     than one signed upload per file. Default 20.
%   UploadTimeout   - seconds to wait for NDI Cloud to record one
%                     document's files. Empty (default) scales with the
%                     number and size of the files.
%   CacheDir        - where local copies are kept. Default: a new folder
%                     in tempdir.
%   KeepLocalCopies - keep CACHEDIR after COMMIT (and on delete).
%                     Default false.
%   Api             - the cloud calls to use; see DEFAULTAPI. Tests pass
%                     a fake (ndi.test.helper.FakeCloudDataset).
%
%   Methods (the part of ndi.session that document builders use):
%     id, newdocument, database_add, database_openbinarydoc,
%     database_closebinarydoc
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
    end

    properties (Access = private)
        api struct
        verbose (1,1) logical = true
        bulkThreshold (1,1) double = 20
        uploadTimeout double = []
        keepLocalCopies (1,1) logical = false
        % Documents sent in DATABASE_ADD, waiting for COMMIT, in order.
        pendingDocs = {}
        % ids added through this writer, and ids confirmed in the cloud.
        knownIds
        cloudIds
        % 'docid|filename' -> uid, for every file sent.
        fileUids
    end

    methods
        function obj = SessionWriter(cloudDatasetId, sessionId, options)
            arguments
                cloudDatasetId (1,:) char {mustBeNonempty}
                sessionId (1,:) char {mustBeNonempty}
                options.Verbose (1,1) logical = true
                options.BulkThreshold (1,1) double {mustBePositive} = 20
                options.UploadTimeout double {mustBeScalarOrEmpty, mustBePositive} = []
                options.CacheDir (1,:) char = ''
                options.KeepLocalCopies (1,1) logical = false
                options.Api = []
            end
            api = options.Api;
            if isempty(api)
                api = ndi.cloud.upload.SessionWriter.defaultApi();
            end
            obj.api = api;
            obj.cloudDatasetId = cloudDatasetId;
            obj.verbose = options.Verbose;
            obj.bulkThreshold = options.BulkThreshold;
            obj.uploadTimeout = options.UploadTimeout;
            obj.keepLocalCopies = options.KeepLocalCopies;
            obj.knownIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            obj.cloudIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            obj.fileUids = containers.Map('KeyType', 'char', 'ValueType', 'char');

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
        % COMMIT - upload the documents held by DATABASE_ADD, in the order added
        %
        %   Their files are already in the cloud and checked. Each
        %   document goes as the JSON a local session would store (series
        %   member paths stripped), which is what uploadDataset sends.
            if obj.committed
                r = obj.report;
                return
            end
            n = numel(obj.pendingDocs);
            obj.say('Adding %d document(s) to session %s of cloud dataset %s ...', ...
                n, obj.sessionReference, obj.cloudDatasetId);
            for k = 1:n
                doc = obj.pendingDocs{k};
                props = did.document.stripSeriesIngestLocations(doc.document_properties);
                [ok, answer] = obj.api.addDocument(obj.cloudDatasetId, ...
                    did.datastructures.jsonencodenan(props));
                if ~ok
                    error('NDI:cloud:SessionWriter:addDocumentFailed', ...
                        ['Could not add document %s (%s) to cloud dataset ' ...
                         '%s: %s. %d of %d documents were added before it; ' ...
                         'their files and the rest of the files are in ' ...
                         'the cloud.'], doc.id(), ...
                        doc.document_properties.document_class.class_name, ...
                        obj.cloudDatasetId, describe(answer), k - 1, n);
                end
                obj.report.documents = obj.report.documents + 1;
                obj.report.documentIds{end+1} = doc.id();
            end
            obj.pendingDocs = {};
            obj.committed = true;
            obj.say('Done: %d document(s), %d file(s), %.1f MB.', ...
                obj.report.documents, obj.report.files, obj.report.bytes / 1e6);
            if ~obj.keepLocalCopies && isfolder(obj.cacheDir)
                rmdir(obj.cacheDir, 's');
            end
            r = obj.report;
        end
    end

    methods (Access = private)
        function addOne(obj, doc)
            sid = char(doc.document_properties.base.session_id);
            if isempty(sid) || strcmp(sid, ndi.session.empty_id())
                doc = doc.set_session_id(obj.sessionId);
            elseif ~strcmp(sid, obj.sessionId)
                error('NDI:cloud:SessionWriter:wrongSession', ...
                    'Document %s belongs to session %s, not to %s.', ...
                    doc.id(), sid, obj.sessionId);
            end

            obj.checkDependencies(doc);

            entries = ndi.cloud.upload.SessionWriter.filesOf(doc);
            if ~isempty(entries)
                obj.sendFiles(doc, entries);
            end

            obj.pendingDocs{end+1} = doc;
            obj.knownIds(doc.id()) = true;
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

        function sendFiles(obj, doc, entries)
            n = numel(entries);
            paths = cell(1, n);
            bytes = zeros(1, n);
            crcs = cell(1, n);
            for i = 1:n
                paths{i} = obj.stage(entries(i));
                d = dir(paths{i});
                bytes(i) = d.bytes;
                crcs{i} = ndi.fun.file.crc32(paths{i});
            end
            uids = {entries.uid};
            label = sprintf('%s %s', ...
                doc.document_properties.document_class.class_name, doc.id());
            obj.say('Sending %d file(s), %.1f MB, for %s ...', n, sum(bytes) / 1e6, label);

            if n >= obj.bulkThreshold
                [ok, msg] = obj.api.uploadFileBatch(obj.cloudDatasetId, paths, bytes);
                if ~ok
                    % Not fatal yet: whatever did not arrive is sent
                    % again one by one below.
                    obj.say('A zip batch failed (%s); checking what arrived.', char(msg));
                end
            else
                for i = 1:n
                    [ok, msg] = obj.api.uploadSingleFile(obj.cloudDatasetId, uids{i}, paths{i});
                    if ~ok
                        obj.say('Sending %s failed (%s); will retry.', uids{i}, char(msg));
                    end
                end
            end

            timeout = obj.uploadTimeout;
            if isempty(timeout)
                timeout = max(120, 30 + 0.05 * n + sum(bytes) / 5e6);
            end
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
                         'local %s). No documents have been added.'], ...
                        nnz(stillBad), label, obj.cloudDatasetId, ...
                        uids{first}, paths{first});
                end
            end

            for i = 1:n
                obj.fileUids([doc.id() '|' entries(i).name]) = uids{i};
            end
            obj.report.files = obj.report.files + n;
            obj.report.bytes = obj.report.bytes + sum(bytes);
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
        %     waitForFileUpload(datasetId, uids, timeout) -> [ok, answer]
        %     lookupFiles(datasetId, uids)         -> [ok, answer]
        %     downloadFile(datasetId, uid, path)   -> [ok, msg]
            api = struct( ...
                'findDocuments', @findCloudDocuments, ...
                'addDocument', @(d, json) ndi.cloud.api.documents.addDocument(d, json), ...
                'uploadSingleFile', @(d, uid, p) ndi.cloud.uploadSingleFile(d, uid, p, ...
                    'checksum', true, 'waitForUpload', false), ...
                'uploadFileBatch', @uploadBatch, ...
                'waitForFileUpload', @(d, uids, t) ndi.cloud.api.files.waitForFileUpload( ...
                    d, string(uids), 'timeout', t), ...
                'lookupFiles', @(d, uids) ndi.cloud.api.files.lookupFiles(d, string(uids)), ...
                'downloadFile', @downloadOne);
        end
    end

    methods (Static, Access = private)
        function entries = filesOf(doc)
        % FILESOF - the files and series members a document carries for ingestion
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
                if isfield(props.files, 'series_info')
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
