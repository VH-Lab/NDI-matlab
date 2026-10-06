classdef calculation < ndi.interaction
    % ndi.calculation - a statement computed from other documents
    %
    % ndi.calculation Methods (beyond ndi.interaction):
    %   inputs  - what it was computed from: statements as ndi.statement
    %             objects, anything else as its ndi.document (a cell array)
    %   interpreter, operating_system - the software it ran under (ndi.entity)
    %
    % software() (from ndi.interaction) is the program that computed it.
    %
    % See also ndi.interaction, ndi.statement.

    methods
        function obj = calculation(container, doc)
            % CALCULATION - use ndi.statement.fromDocument
            if nargin == 0
                container = []; doc = [];
            end
            obj = obj@ndi.interaction(container, doc);
        end

        function x = inputs(obj)
            % INPUTS - what the calculation was computed from (a cell array)
            x = {};
            ids = ndi.v2.edgeIds(obj.document_properties(), 'input_id');
            for i = 1:numel(ids)
                d = ndi.v2.getDocument(obj.container_, ids{i});
                if isempty(d), continue; end
                if any(strcmp(ndi.v2.classChain(ndi.v2.props(d)), 'subject_statement'))
                    x{end+1} = ndi.statement.fromDocument(obj.container_, d); %#ok<AGROW>
                else
                    x{end+1} = d; %#ok<AGROW>
                end
            end
        end

        function s = interpreter(obj)
            % INTERPRETER - the interpreter entity(s) (e.g. MATLAB), a cell array
            s = obj.entitiesAt('interpreter_id');
        end

        function s = operating_system(obj)
            % OPERATING_SYSTEM - the operating-system entity(s), a cell array
            s = obj.entitiesAt('operating_system_id');
        end
    end
end
