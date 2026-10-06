classdef observation < ndi.interaction
    % ndi.observation - a statement of what was observed or measured of a subject
    %
    % Everything it does comes from ndi.interaction and ndi.statement.
    %
    % See also ndi.interaction, ndi.statement.

    methods
        function obj = observation(container, doc)
            % OBSERVATION - use ndi.statement.fromDocument
            if nargin == 0
                container = []; doc = [];
            end
            obj = obj@ndi.interaction(container, doc);
        end
    end
end
