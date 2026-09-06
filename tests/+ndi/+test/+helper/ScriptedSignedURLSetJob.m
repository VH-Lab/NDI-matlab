classdef ScriptedSignedURLSetJob < ndi.cloud.api.implementation.documents.WaitForSignedURLSetJob
% SCRIPTEDSIGNEDURLSETJOB - a WaitForSignedURLSetJob that returns canned states.
%
% Overrides the pollStatus seam so the terminal-state, timeout and backoff
% logic can be exercised without a server. STATES is a cell array of structs
% with fields:
%   ok     - logical, what pollStatus should report
%   status - the status struct, normally carrying a 'state' field
%
% Calls past the end repeat the last entry, which is what a timeout test wants.
% Give the constructor small intervals so the real pause() costs milliseconds.

    properties
        states = {}
        callCount = 0
    end

    methods
        function this = ScriptedSignedURLSetJob(states, varargin)
            this@ndi.cloud.api.implementation.documents.WaitForSignedURLSetJob(varargin{:});
            this.states = states;
        end
    end

    methods (Access = protected)
        function [ok, status, apiResponse, apiURL] = pollStatus(this)
            this.callCount = this.callCount + 1;
            entry = this.states{min(this.callCount, numel(this.states))};
            ok = entry.ok;
            status = entry.status;
            apiResponse = [];
            apiURL = "scripted://job";
        end
    end
end
