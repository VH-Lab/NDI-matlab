classdef FakeSearchSession
%FAKESEARCHSESSION A session whose DATABASE_SEARCH is answered by a function.
%
%   S = ndi.unittest.vintage.FakeSearchSession(RESPOND) returns an object
%   whose database_search(Q) returns RESPOND(Q). Nothing else of a session
%   is provided, so a test sees exactly which searches a reader makes.
%
%   See also: ndi.unittest.vintage.TestElementDocsBothVintages

    properties
        Respond
    end

    methods
        function obj = FakeSearchSession(respond)
            arguments
                respond (1,1) function_handle
            end
            obj.Respond = respond;
        end

        function d = database_search(obj, query)
            d = obj.Respond(query);
        end
    end
end
