classdef ScriptedDocumentCount < ndi.cloud.api.implementation.documents.WaitForDocumentCount
% SCRIPTEDDOCUMENTCOUNT - a WaitForDocumentCount that returns canned counts.
%
% Overrides the pollCount seam so the target, timeout and retry logic can
% be exercised without a server. POLLS is a cell array of structs with
% fields:
%   ok    - logical, what pollCount should report
%   count - the count (or an error struct when ok is false)
%
% Calls past the end repeat the last entry, which is what a timeout test
% wants. Give the constructor small intervals so the real pause() costs
% milliseconds.

    properties
        polls = {}
        callCount = 0
    end

    methods
        function this = ScriptedDocumentCount(polls, varargin)
            this@ndi.cloud.api.implementation.documents.WaitForDocumentCount(varargin{:});
            this.polls = polls;
        end
    end

    methods (Access = protected)
        function [ok, count, apiResponse, apiURL] = pollCount(this)
            this.callCount = this.callCount + 1;
            entry = this.polls{min(this.callCount, numel(this.polls))};
            ok = entry.ok;
            count = entry.count;
            apiResponse = [];
            apiURL = "scripted://document-count";
        end
    end
end
