classdef MockDoc < handle
    % MOCKDOC - a minimal stand-in for an ndi.document in the JRCLUST tests.
    %
    %   D = MockDoc(ID) makes a document with that id.
    %   D = MockDoc(ID, PROPS) also sets its document_properties.
    %   D = MockDoc(ID, PROPS, DEPS) also sets its dependencies, a struct whose
    %       field names are dependency names (e.g. element_id).

    properties
        idString = ''
        document_properties = struct()
        dependencies = struct()
    end

    methods
        function obj = MockDoc(idString, props, deps)
            arguments
                idString (1,:) char
                props (1,1) struct = struct()
                deps (1,1) struct = struct()
            end
            obj.idString = idString;
            obj.document_properties = props;
            obj.dependencies = deps;
        end

        function i = id(obj)
            i = obj.idString;
        end

        function v = dependency_value(obj, name)
            v = '';
            if isfield(obj.dependencies, name),
                v = obj.dependencies.(name);
            end;
        end
    end

    methods (Static)
        function d = clusters(idString, checksum, elementId)
            % CLUSTERS - a mock jrclust_clusters document with a checksum
            arguments
                idString (1,:) char
                checksum (1,:) char
                elementId (1,:) char = 'mock_probe_id'
            end
            props = struct('jrclust_clusters', ...
                struct('res_mat_MD5_checksum', checksum));
            d = ndi.unittest.fun.probe.import.jrclust.MockDoc(idString, props, ...
                struct('element_id', elementId));
        end
    end
end
