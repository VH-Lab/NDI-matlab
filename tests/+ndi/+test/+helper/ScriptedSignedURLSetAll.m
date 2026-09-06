classdef ScriptedSignedURLSetAll < ndi.cloud.api.implementation.files.GetSignedURLSetAll
% SCRIPTEDSIGNEDURLSETALL - a GetSignedURLSetAll that returns canned pages.
%
% Overrides the fetchPage seam so the paging, merging and cursor-advance logic
% can be exercised without a server. Records the cursor it was handed on each
% call, so a test can assert the walk followed nextCursor rather than merely
% arriving at the right union.
%
% PAGES is a cell array of structs with fields:
%   ok   - logical, what fetchPage should report
%   page - the page struct (files/nextCursor/expiresAt), or the error body
%          when ok is false
%
% Calls past the end of PAGES repeat the last entry, so a test that means to
% assert "stops here" fails loudly by looping rather than passing by accident.

    properties
        pages = {}
        cursorsSeen = {}
        callCount = 0
    end

    methods
        function this = ScriptedSignedURLSetAll(pages, varargin)
            this@ndi.cloud.api.implementation.files.GetSignedURLSetAll(varargin{:});
            this.pages = pages;
        end
    end

    methods (Access = protected)
        function [ok, page, apiResponse, apiURL] = fetchPage(this, cursor)
            this.callCount = this.callCount + 1;
            this.cursorsSeen{end+1} = char(cursor);
            entry = this.pages{min(this.callCount, numel(this.pages))};
            ok = entry.ok;
            page = entry.page;
            apiResponse = [];
            apiURL = "scripted://page";
        end
    end
end
