function q = subjectNamingManipulations()
%SUBJECTNAMINGMANIPULATIONS The manipulations that name a retired stimulator's subject.
%
%   Q = ndi.vintage.subjectNamingManipulations() matches the stimulus
%   presentation manipulations (value kind `item`,
%   ndi.migrate.internal.stimulusPresentationToItem) and the bath
%   manipulations (value kind `formulation`,
%   ndi.migrate.internal.stimulusBathToBath): the statements NDI's second
%   pass retires a stimulator's `observes` relation on (Decided by Jess
%   Haley, 2026-11-17 [observes retires in the second pass], 2026-11-19
%   [bath manipulation retires observes], did-schema
%   did_v2_go_forward_class_audit.md; ndi.migrate.internal.observesRetirement),
%   so the ones ndi.vintage.elementFields reads the subject back from.
%   Combine it with an `instrument_id` edge query.
%
%   See also ndi.vintage.elementFields, ndi.vintage.prefetchElementFields.

q = ndi.v2.statementQuery('manipulation', 'item') | ...
    ndi.v2.statementQuery('manipulation', 'formulation');
end
