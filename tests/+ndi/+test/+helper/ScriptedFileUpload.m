classdef ScriptedFileUpload < ndi.cloud.api.implementation.files.WaitForFileUpload
% SCRIPTEDFILEUPLOAD - a WaitForFileUpload that returns canned lookups.
%
% Overrides the pollStatus seam so the completion, timeout and retry logic
% can be exercised without a server. RESULTS is a cell array of structs
% with fields:
%   ok     - logical, what pollStatus should report
%   result - the lookupFiles answer, normally a struct with 'files' (Nx1
%            struct array: uid, uploaded, size, crc32) and 'missing'
%
% Calls past the end repeat the last entry, which is what a timeout test
% wants. Give the constructor small intervals so the real pause() costs
% milliseconds. polledUids records the uids asked for on each call.

    properties
        results = {}
        callCount = 0
        polledUids = {}
    end

    methods
        function this = ScriptedFileUpload(results, varargin)
            arguments
                results cell
            end
            arguments (Repeating)
                varargin
            end
            this@ndi.cloud.api.implementation.files.WaitForFileUpload(varargin{:});
            this.results = results;
        end
    end

    methods (Static)
        function row = fileRow(uid, uploaded)
            % One lookupFiles row, as lookupFilesResult returns it.
            arguments
                uid {mustBeText}
                uploaded (1,1) logical
            end
            row = struct('uid', char(uid), 'uploaded', logical(uploaded), ...
                'size', double(uploaded) * 47, 'crc32', '');
        end
    end

    methods (Access = protected)
        function [ok, result, apiResponse, apiURL] = pollStatus(this, uids)
            arguments
                this (1,1) ndi.test.helper.ScriptedFileUpload
                uids {mustBeText}
            end
            this.callCount = this.callCount + 1;
            this.polledUids{end+1} = uids;
            entry = this.results{min(this.callCount, numel(this.results))};
            ok = entry.ok;
            result = entry.result;
            apiResponse = [];
            apiURL = "scripted://lookup";
        end
    end
end
