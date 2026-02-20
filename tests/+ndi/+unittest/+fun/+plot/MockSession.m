classdef MockSession < ndi.session
    methods
        function obj = MockSession()
            obj = obj@ndi.session('mock_session');
        end
    end
end
