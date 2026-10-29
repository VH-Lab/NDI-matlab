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

    properties
        DatasetId = 'aaaaaaaaaaaaaaaaaaaaaaaa'
        docs = {}
        fileDir
        CorruptOnce = {}
        CorruptAlways = {}
        RecordCrc (1,1) logical = true
        FailAdd (1,1) logical = false
        singleUploads = 0
        batchUploads = 0
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
                'waitForFileUpload', @(d, uids, t) obj.waitForFileUpload(d, uids, t), ...
                'lookupFiles', @(d, uids) obj.lookupFiles(d, uids), ...
                'downloadFile', @(d, uid, p) obj.downloadFile(d, uid, p));
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

        function [ok, answer] = waitForFileUpload(~, ~, ~, ~)
            % Uploads here are recorded at once; lookupFiles tells the rest.
            ok = true;
            answer = struct('state', 'complete');
        end

        function [ok, answer] = lookupFiles(obj, ~, uids)
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
