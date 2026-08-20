classdef MockSession < handle
    % MOCKSESSION - a minimal stand-in for an ndi.session in the JRCLUST tests.
    %
    % Provides the session path (a caller-supplied folder) and a database that
    % answers every search with nothing.

    properties
        reference = 'mock_session'
        path = ''
    end

    methods
        function obj = MockSession(sessionPath)
            arguments
                sessionPath (1,:) char
            end
            obj.path = sessionPath;
        end

        function docs = database_search(~, ~)
            docs = {};
        end

        function probes = getprobes(~, varargin)
            probes = {ndi.unittest.fun.probe.import.jrclust.MockProbe()};
        end
    end
end
