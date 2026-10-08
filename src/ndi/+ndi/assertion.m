classdef assertion < ndi.statement
    % ndi.assertion - a statement that simply holds of a subject
    %
    % A subject's species, strain, sex, or its inclusion in an analysis: a
    % variable and a value, with no time, method or instrument. Everything
    % it does comes from ndi.statement.
    %
    % See also ndi.statement, ndi.entity/assertions.

    methods
        function obj = assertion(container, doc)
            % ASSERTION - use ndi.statement.fromDocument
            if nargin == 0
                container = []; doc = [];
            end
            obj = obj@ndi.statement(container, doc);
        end
    end
end
