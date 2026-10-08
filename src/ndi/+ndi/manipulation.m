classdef manipulation < ndi.interaction
    % ndi.manipulation - a statement of what was done to a subject
    %
    % ndi.manipulation Methods (beyond ndi.interaction):
    %   formulation - for a dose: what was given (an ndi.value of class
    %                 'formulation'; [] when the statement names none)
    %
    % See also ndi.interaction, ndi.statement.

    methods
        function obj = manipulation(container, doc)
            % MANIPULATION - use ndi.statement.fromDocument
            if nargin == 0
                container = []; doc = [];
            end
            obj = obj@ndi.interaction(container, doc);
        end

        function f = formulation(obj)
            % FORMULATION - what a dose gave: an ndi.value ([] when none)
            %
            % A formulation is a data_type, not an entity: its value holds
            % the ingredients (and their own formulations) as stored.
            f = [];
            ids = ndi.v2.edgeIds(obj.document_properties(), 'formulation_id');
            if isempty(ids), return; end
            d = ndi.v2.getDocument(obj.container_, ids{1});
            if isempty(d), return; end
            p = ndi.v2.props(d);
            f = ndi.value('formulation', ndi.v2.blockOf(p, 'formulation', 'value', []));
        end
    end
end
