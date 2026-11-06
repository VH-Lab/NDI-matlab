classdef FakeCloudDataset < handle
% FAKECLOUDDATASET - an in-memory NDI Cloud dataset for ndi.cloud.upload.SessionWriter
%
%   F = ndi.test.helper.FakeCloudDataset();
%   sid = F.addSession('my_session');
%   subj = F.addSubject(sid, 'mouse1@lab');
%   W = ndi.cloud.upload.SessionWriter(F.DatasetId, sid, 'Api', F.api());
%
%   Holds documents as property structs and files in a temp folder under
%   their uids, and answers SessionWriter's calls (see
%   ndi.cloud.upload.SessionWriter.defaultApi) the way NDI Cloud does:
%   queries are evaluated with did.datastructures.fieldsearch, and
%   lookupFiles reports each stored file's size and CRC-32.
%
%   Faults, for the verification paths:
%     CorruptOnce   - uids whose next upload stores the wrong bytes
%     CorruptAlways - uids whose every upload stores the wrong bytes
%     RecordCrc     - false: report crc32 '' (compare size instead)
%     FailAdd       - true: addDocument fails
%     DeferSends    - true: a background send (startSend) stores its files
%                     only when it is waited for, as a slow upload would
%     FailSends     - true: a background send stores nothing and reports
%                     failure, so the writer must send the files itself
%     FailFirstSends - N: a background send does not store its first N
%                     files, and reports them failed (as curl names them)

    properties
        DatasetId = 'aaaaaaaaaaaaaaaaaaaaaaaa'
        docs = {}
        fileDir
        CorruptOnce = {}
        CorruptAlways = {}
        RecordCrc (1,1) logical = true
        FailAdd (1,1) logical = false
        % Transient faults, for the retry paths: the next FailLookups calls
        % to lookupFiles fail; with LoseAddReply the next addDocument
        % stores the document but reports failure, as a lost reply would.
        FailLookups (1,1) double = 0
        LoseAddReply (1,1) logical = false
        DeferSends (1,1) logical = false
        FailSends (1,1) logical = false
        FailFirstSends (1,1) double = 0
        singleUploads = 0
        waitedFor = {}         % the uids each waitForFileUpload was asked about
        batchUploads = 0
        backgroundSends = 0    % startSend calls
        backgroundFiles = 0    % files those sends stored
        zipSends = 0           % startZipSend calls (one zip each)
        urlBatches = 0         % uploadURLs calls (many URLs each)
        addedJson = {}
    end

    methods
        function obj = FakeCloudDataset()
            obj.fileDir = tempname;
            mkdir(obj.fileDir);
        end

        function delete(obj)
            if isfolder(obj.fileDir)
                rmdir(obj.fileDir, 's');
            end
        end

        function sid = addSession(obj, reference)
            sid = char(did.ido.unique_id());
            info = struct('session_id', sid, 'session_reference', reference, ...
                'is_linked', 0, 'session_creator', 'ndi.session.dir', ...
                'session_creator_input1', reference, ...
                'session_creator_input2', '', 'session_creator_input3', '', ...
                'session_creator_input4', '', 'session_creator_input5', '', ...
                'session_creator_input6', '');
            d = ndi.document('session_in_a_dataset', 'session_in_a_dataset', info);
            obj.docs{end+1} = d.document_properties;
        end

        function id = addSubject(obj, sessionId, localIdentifier)
            d = ndi.document('subject', 'base.session_id', sessionId, ...
                'subject.local_identifier', localIdentifier);
            obj.docs{end+1} = d.document_properties;
            id = d.id();
        end

        function a = api(obj)
            a = struct( ...
                'findDocuments', @(d, q) obj.findDocuments(d, q), ...
                'addDocument', @(d, json) obj.addDocument(d, json), ...
                'uploadSingleFile', @(d, uid, p) obj.uploadSingleFile(d, uid, p), ...
                'uploadFileBatch', @(d, paths, bytes) obj.uploadFileBatch(d, paths, bytes), ...
                'uploadURL', @(d, uid, crc) obj.uploadURL(d, uid, crc), ...
                'startSend', @(urls, paths, crcs, uids, folder, n) ...
                    obj.startSend(urls, paths, crcs, uids, folder, n), ...
                'uploadURLs', @(d, uids, crcs, folder, n) obj.uploadURLs(d, uids, crcs, folder, n), ...
                'startZipSend', @(d, uids, paths, folder) obj.startZipSend(d, uids, paths, folder), ...
                'waitForFileUpload', @(d, uids, t) obj.waitForFileUpload(d, uids, t), ...
                'lookupFiles', @(d, uids) obj.lookupFiles(d, uids), ...
                'downloadFile', @(d, uid, p) obj.downloadFile(d, uid, p), ...
                'updateDocument', @(d, ndiId, json) obj.updateDocument(d, ndiId, json));
        end

        function out = findDocuments(obj, ~, q)
            out = {};
            for i = 1:numel(obj.docs)
                if did.datastructures.fieldsearch(obj.docs{i}, q.to_searchstructure())
                    out{end+1} = obj.docs{i}; %#ok<AGROW>
                end
            end
        end

        function out = docsOfClass(obj, className)
            out = obj.findDocuments('', ndi.query('', 'isa', className));
        end

        function [ok, answer] = addDocument(obj, ~, json)
            if obj.FailAdd
                ok = false;
                answer = struct('message', 'refused by the fake');
                return
            end
            obj.addedJson{end+1} = char(json);
            obj.docs{end+1} = jsondecode(char(json));
            ok = true;
            answer = struct('id', 'fake');
            if obj.LoseAddReply
                obj.LoseAddReply = false;
                ok = false;
                answer = struct('message', 'connection reset (fake)');
            end
        end

        function [ok, answer] = updateDocument(obj, ~, ndiId, json)
            ok = false;
            answer = struct('message', 'no such document in the fake');
            for i = 1:numel(obj.docs)
                if strcmp(obj.docs{i}.base.id, ndiId)
                    obj.docs{i} = jsondecode(char(json));
                    ok = true;
                    answer = struct('id', 'fake');
                    return
                end
            end
        end

        function tf = hasDocument(obj, ndiId)
            tf = any(cellfun(@(d) strcmp(d.base.id, ndiId), obj.docs));
        end

        function [ok, msg] = uploadSingleFile(obj, ~, uid, p)
            obj.singleUploads = obj.singleUploads + 1;
            obj.store(char(uid), char(p));
            ok = true;
            msg = '';
        end

        function [ok, msg] = uploadFileBatch(obj, ~, paths, ~)
            obj.batchUploads = obj.batchUploads + 1;
            for i = 1:numel(paths)
                [~, uid, ext] = fileparts(paths{i});
                obj.store([uid ext], paths{i});
            end
            ok = true;
            msg = '';
        end

        function [ok, url] = uploadURL(~, ~, uid, ~)
            ok = true;
            url = ['https://fake.invalid/upload/' char(uid)];
        end

        function [ok, urls, msg] = uploadURLs(obj, d, uids, crcs, ~, ~)
            obj.urlBatches = obj.urlBatches + 1;
            urls = cell(1, numel(uids));
            for i = 1:numel(uids)
                [~, urls{i}] = obj.uploadURL(d, uids{i}, crcs{i});
            end
            ok = true;
            msg = '';
        end

        function sender = startZipSend(obj, ~, uids, paths, ~)
        % As startSend (DeferSends and FailSends apply), but one zip.
            obj.zipSends = obj.zipSends + 1;
            sender = obj.startSend({}, paths, {}, uids, '', 1);
            obj.backgroundSends = obj.backgroundSends - 1;
        end

        function sender = startSend(obj, ~, paths, ~, uids, ~, ~)
        % A background send: a struct whose WAIT reports how it went.
            obj.backgroundSends = obj.backgroundSends + 1;
            if obj.FailSends
                sender = struct('wait', @(varargin) obj.sendResult(false, uids));
            elseif obj.FailFirstSends > 0
                k = min(obj.FailFirstSends, numel(uids));
                obj.finishSend(uids(k+1:end), paths(k+1:end));
                sender = struct('wait', @(varargin) obj.sendResult(false, uids(1:k)));
            elseif obj.DeferSends
                sender = struct('wait', @(varargin) obj.finishSend(uids, paths));
            else
                obj.finishSend(uids, paths);
                sender = struct('wait', @(varargin) obj.sendResult(true));
            end
        end

        function [ok, msg, failed] = finishSend(obj, uids, paths)
            for i = 1:numel(uids)
                if isfile(paths{i})
                    obj.store(char(uids{i}), char(paths{i}));
                    obj.backgroundFiles = obj.backgroundFiles + 1;
                end
            end
            [ok, msg, failed] = obj.sendResult(true);
        end

        function [ok, msg, failed] = sendResult(~, ok, failed)
            % FAILED: the uids the send names as not sent.
            msg = '';
            if nargin < 3, failed = {}; end
            if ~ok, msg = 'curl exited with status 7 (fake)'; end
        end

        function [ok, answer] = waitForFileUpload(obj, ~, uids, ~)
            % Uploads here are recorded at once; lookupFiles tells the rest.
            obj.waitedFor{end+1} = cellstr(uids);
            ok = true;
            answer = struct('state', 'complete');
        end

        function [ok, answer] = lookupFiles(obj, ~, uids)
            if obj.FailLookups > 0
                obj.FailLookups = obj.FailLookups - 1;
                ok = false;
                answer = struct('message', 'network unreachable (fake)');
                return
            end
            uids = cellstr(uids);
            rows = struct('uid', {}, 'uploaded', {}, 'size', {}, 'crc32', {});
            missing = strings(1, 0);
            for i = 1:numel(uids)
                p = fullfile(obj.fileDir, uids{i});
                if ~isfile(p)
                    missing(end+1) = string(uids{i}); %#ok<AGROW>
                    continue
                end
                d = dir(p);
                crc = '';
                if obj.RecordCrc
                    crc = ndi.fun.file.crc32(p);
                end
                rows(end+1, 1) = struct('uid', uids{i}, 'uploaded', true, ...
                    'size', d.bytes, 'crc32', crc); %#ok<AGROW>
            end
            ok = true;
            answer = struct('files', rows, 'missing', missing);
        end

        function [ok, msg] = downloadFile(obj, ~, uid, p)
            [ok, msg] = copyfile(fullfile(obj.fileDir, char(uid)), p, 'f');
        end

        function tf = hasFile(obj, uid)
            tf = isfile(fullfile(obj.fileDir, char(uid)));
        end

        function b = fileBytes(obj, uid)
            fid = fopen(fullfile(obj.fileDir, char(uid)), 'r');
            b = fread(fid, Inf, '*uint8');
            fclose(fid);
        end
    end

    methods (Access = private)
        function store(obj, uid, p)
            dest = fullfile(obj.fileDir, uid);
            copyfile(p, dest, 'f');
            once = any(strcmp(obj.CorruptOnce, uid));
            if once || any(strcmp(obj.CorruptAlways, uid))
                fid = fopen(dest, 'a');
                fwrite(fid, uint8(255));
                fclose(fid);
                if once
                    obj.CorruptOnce(strcmp(obj.CorruptOnce, uid)) = [];
                end
            end
        end
    end
end
