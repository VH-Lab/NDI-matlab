classdef FakeRecordingServer < handle
    % FAKERECORDINGSERVER - NDI Cloud's file-recording step, scripted
    %
    % Stands in for ndi.cloud.api.files.waitForFileUpload and
    % ndi.cloud.uploadSingleFile in tests of
    % ndi.cloud.upload.internal.confirmFilesRecorded. Each WAIT call first
    % records the uids scheduled for it (Schedule{n} for the n-th call), then
    % reports which of the uids asked about are still unrecorded. RESEND
    % records a uid at once unless it is in NeverRecord (a server that keeps
    % failing) or refuses it if it is in RefuseResend.

    properties
        Schedule = {}            % cell of string arrays, one per wait call
        NeverRecord = strings(1, 0)
        RefuseResend = strings(1, 0)
        ThrowOnResend = strings(1, 0)  % as uploadSingleFile does for a missing local file
        FailBatchResend = false        % a zip batch resend reports failure (after sending)
        batchResends = {}              % the uids of each zip batch resend
        recorded                 % containers.Map uid -> true
        waitCalls = 0
        waitTimeouts = []
        resent = strings(1, 0)
    end

    methods
        function obj = FakeRecordingServer()
            obj.recorded = containers.Map('KeyType', 'char', 'ValueType', 'logical');
        end

        function [b, answer] = wait(obj, ids, timeout)
            obj.waitCalls = obj.waitCalls + 1;
            obj.waitTimeouts(end+1) = timeout;
            if obj.waitCalls <= numel(obj.Schedule)
                obj.record(obj.Schedule{obj.waitCalls});
            end
            ids = string(ids);
            isDone = arrayfun(@(u) isKey(obj.recorded, char(u)), ids);
            pending = ids(~isDone);
            b = isempty(pending);
            state = 'complete';
            if ~b, state = 'timeout'; end
            answer = struct('state', state, 'pending', pending, 'elapsed', timeout);
        end

        function [b, msg] = resend(obj, uid, p)
            uid = string(uid);
            if ismember(uid, obj.ThrowOnResend)
                error('test:FakeRecordingServer:noFile', 'No such file: %s', p);
            end
            if ismember(uid, obj.RefuseResend)
                b = false;
                msg = 'refused by the fake';
                return
            end
            obj.resent(end+1) = uid;
            if ~ismember(uid, obj.NeverRecord)
                obj.record(uid);
            end
            b = true;
            msg = '';
        end

        function [b, msg] = resendBatch(obj, ids, ~)
            ids = reshape(string(ids), 1, []);
            obj.batchResends{end+1} = ids;
            obj.resent = [obj.resent ids];
            obj.record(ids(~ismember(ids, obj.NeverRecord)));
            b = ~obj.FailBatchResend;
            msg = '';
            if ~b, msg = 'batch refused by the fake'; end
        end

        function record(obj, ids)
            for u = reshape(string(ids), 1, [])
                obj.recorded(char(u)) = true;
            end
        end
    end
end
