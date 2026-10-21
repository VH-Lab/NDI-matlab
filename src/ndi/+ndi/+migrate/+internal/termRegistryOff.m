function restore = termRegistryOff()
%TERMREGISTRYOFF Turn DID's T19 TermRegistry check off until RESTORE is cleared.
%
%   RESTORE = ndi.migrate.internal.termRegistryOff() returns an onCleanup that
%   puts the previous setting back. The second pass builds stimulus documents
%   whose terms are labels the registry does not carry yet (V_eta_method_plan.md
%   follow-up (a)); DID-matlab's own batch passes turn the check off the same
%   way while they build (did2.convert.epochMint, foldGenericFiles, ...). On a
%   DID-matlab without the check, this does nothing.
restore = onCleanup(@() []);
try
    prev = did2.schema.cache.strictMode('TermRegistry', false);
    restore = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev));
catch
end
end
