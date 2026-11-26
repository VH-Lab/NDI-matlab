classdef MockBinaryFile < handle
    % MockBinaryFile - an open binary document holding BYTES
    %
    % F = ndi.unittest.daq.reader.MockBinaryFile(BYTES); F.fread(Inf, 'uint8')
    % returns every byte as a double column, as fread does.

    properties
        Bytes
    end

    methods
        function obj = MockBinaryFile(bytes)
            obj.Bytes = uint8(bytes(:));
        end

        function x = fread(obj, n, precision) %#ok<INUSD>
            x = double(obj.Bytes);
        end
    end
end
