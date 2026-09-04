classdef MockSession < handle
    % MOCKSESSION - a minimal stand-in for an ndi.session in the JRCLUST tests.
    %
    % Provides the session path (a caller-supplied folder) and a database that,
    % by default, answers every search with nothing.
    %
    % To test code that reads or writes the database, set SearchResults to a cell
    % array of responses: each database_search call returns the next one (and {}
    % once they run out). The queries that were made, the documents that were
    % added, and the documents that were removed are recorded in Queries, Added
    % and Removed.

    properties
        reference = 'mock_session'
        path = ''
        idString = 'mock_session_id'
        Probes = {}          % probes getprobes returns ({} => one MockProbe)
        SearchResults = {}   % queued database_search responses, consumed in order
        Queries = {}         % every query database_search was called with
        Added = {}           % every document passed to database_add
        Removed = {}         % every document set passed to database_rm
    end

    methods
        function obj = MockSession(sessionPath)
            arguments
                sessionPath (1,:) char
            end
            obj.path = sessionPath;
        end

        function i = id(obj)
            i = obj.idString;
        end

        function docs = database_search(obj, q)
            obj.Queries{end+1} = q;
            docs = {};
            if ~isempty(obj.SearchResults),
                docs = obj.SearchResults{1};
                obj.SearchResults(1) = [];
            end;
        end

        function database_add(obj, doc)
            obj.Added{end+1} = doc;
        end

        function database_rm(obj, docs)
            obj.Removed{end+1} = docs;
        end

        function probes = getprobes(obj, varargin)
            if isempty(obj.Probes),
                probes = {ndi.unittest.fun.probe.import.jrclust.MockProbe()};
            else,
                probes = obj.Probes;
            end;
        end
    end
end
