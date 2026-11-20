classdef MockBinarySession < handle
    % MockBinarySession - serves binary documents' bytes, as a session does
    %
    % S = ndi.unittest.daq.reader.MockBinarySession(FILES)
    %
    % S.database_openbinarydoc(DOC, NAME) returns an
    % ndi.unittest.daq.reader.MockBinaryFile of DOC.bytes when DOC is a
    % struct with a `bytes` field (a v2 data body: member body_data_0), else
    % of FILES(NAME) (FILES a containers.Map from a v1 document's file name
    % to its bytes). S.database_closebinarydoc does nothing.

    properties
        Files
    end

    methods
        function obj = MockBinarySession(files)
            if nargin < 1
                files = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
            obj.Files = files;
        end

        function f = database_openbinarydoc(obj, doc, name)
            if isstruct(doc) && isfield(doc, 'bytes')
                f = ndi.unittest.daq.reader.MockBinaryFile(doc.bytes);
            else
                f = ndi.unittest.daq.reader.MockBinaryFile(obj.Files(name));
            end
        end

        function database_closebinarydoc(obj, f) %#ok<INUSD>
        end
    end
end
