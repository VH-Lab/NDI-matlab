function assertDIDInstalled()
    s = which('did_Init');

    if isempty(s)
        ME = MException("NDI:DIDNotFound", ...
            "DID-MATLAB was not found. Please ensure DID-MATLAB is installed and added to MATLAB's search path");
        throwAsCaller(ME)
    end
end
