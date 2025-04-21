function assertDIDInstalled()
    s = which('did.database');

    if isempty(s)
        ME = MException("NDI:DIDNotFound", ...
            "DID-MATLAB was not found. Please ensure DID-MATLAB is installed and added to MATLAB's search path");
        throwAsCaller(ME)
    end
end
