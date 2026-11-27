function q = subjectNamingManipulations()
%SUBJECTNAMINGMANIPULATIONS The manipulations an element's subject is read back from.
%
%   Q = ndi.vintage.subjectNamingManipulations() matches every manipulation:
%   the stimulus presentation manipulations (value kind `item`,
%   ndi.migrate.internal.stimulusPresentationToItem), the bath manipulations
%   (value kind `formulation`, ndi.migrate.internal.stimulusBathToBath) and
%   any other (a per-epoch Stimulator manipulation, value kind `term`,
%   DID-matlab resolveEpochProbemap). Combine it with an `instrument_id` edge
%   query.
%
%   Decided by Jess Haley, 2026-11-26 [no observes relation in v2] (did-schema
%   docs/plans/did_v2_standing_wiring_plan.md): v2 has no `observes`
%   relation; "the animal is the `entity_id` of the observations and
%   manipulations made with the element, or, where none names it, is carried
%   as the element's subject". NDI's second pass carries the v1 subject
%   unless every manipulation made with the element names that one animal
%   (ndi.migrate.internal.observesRetirement). Until that decision only the
%   presentations and baths were read ([observes retires in the second
%   pass], [bath manipulation retires observes], did_v2_go_forward_class_audit.md).
%
%   See also ndi.vintage.elementFields, ndi.vintage.prefetchElementFields.

q = ndi.v2.isaQuery('manipulation') | ...
    ndi.v2.statementQuery('manipulation', 'item') | ...
    ndi.v2.statementQuery('manipulation', 'formulation');
end
