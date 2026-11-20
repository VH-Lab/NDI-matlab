function label = elementLabel(which)
%ELEMENTLABEL The phrase that marks a subject as having been an element.
%
%   LABEL = ndi.vintage.elementLabel('class')  -> 'ndi element class'
%   LABEL = ndi.vintage.elementLabel('type')   -> 'element type'
%
%   WHY THIS IS ITS OWN FUNCTION
%   ----------------------------
%   V_eta turns one v1 `element` document into a `subject` plus satellites.
%   The class name that used to sit on the element -- the thing
%   `getprobes` matches on -- moves into a `term_assertion` that points
%   back at the subject and reads, in effect:
%
%       subject_statement.variable.name = 'ndi element class'
%       term.value.name                 = 'ndi.probe.timeseries.mfdaq'
%
%   That phrase is the ONLY thing separating a subject that was a piece of
%   apparatus from a subject that is an animal. It is written in exactly
%   one place on the migrator side:
%
%       DID-matlab +migrators_j/element.m:104
%           kindAssertion(preBody, elementId, 'ndi element class', ndiClass)
%       DID-matlab +migrators_j/element.m:101
%           kindAssertion(preBody, elementId, 'element type', type)
%
%   ...and it needs to be written once here to read it back. Two typed
%   phrases in two repositories with nothing comparing them is how
%   `getprobes` comes to return nothing at all and report no error -- the
%   silent-empty failure this whole layer exists to remove, reintroduced
%   one level up. `ndi.unittest.vintage.TestElementLabelMatchesMigrator`
%   opens the migrator and asserts both phrases still match.
%
%   THE CLASS VARIABLE IS NOW A NODE. Decided by Jess Haley, 2026-11-19
%   [variable terms batch 1] (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md): the v1 'ndi element
%   class' variable becomes the registered node EMPTY:0000401 "software
%   class" (ndi.vintage.elementClassVariable). The readers match the node
%   first and still accept this phrase, which databases migrated before the
%   decision hold (ndi.vintage.isElementClassVariable,
%   ndi.vintage.elementClassQuery). 'class' here returns that OLD phrase.
%   The test above accepts the migrator writing either the node lookup or
%   the phrase, and fails when it writes neither.
%
%   See also: ndi.vintage.elementSubjectDocs, ndi.vintage.map,
%             ndi.vintage.elementClassVariable, ndi.vintage.elementClassQuery.

arguments
    which (1,:) char {mustBeMember(which, {'class', 'type'})}
end

switch which
    case 'class'
        label = 'ndi element class';
    case 'type'
        label = 'element type';
end
end
