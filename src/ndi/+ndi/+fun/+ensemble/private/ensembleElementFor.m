function ens = ensembleElementFor(S, probe)
% ENSEMBLEELEMENTFOR - find or create the ndi.element.ensemble built on a probe
%
% ENS = ensembleElementFor(S, PROBE)
%
% Returns the ndi.element.ensemble whose underlying element is PROBE (an
% ndi.element/ndi.probe object). If one does not yet exist in the session S it
% is constructed (which adds its element document to the database); if it does,
% the existing one is returned. The ensemble element is named
% [PROBE.name '_ensemble'] with the probe's reference number.
%
% This is a private helper for the ndi.fun.ensemble package.

    name = [probe.name '_ensemble'];
    ens = ndi.element.ensemble(S, name, probe.reference, probe, probe.subject_id);

end % ensembleElementFor()
