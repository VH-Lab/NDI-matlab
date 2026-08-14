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
%   IT IS FREE TEXT, ON PURPOSE FOR NOW. The tidy form is a bound
%   ontology term rather than a phrase, and `subject_statement.variable`
%   is already bound in FORM (`node_form: curie`) but not in VOCABULARY --
%   which is did-schema's open T8 item, blocked on a term list that lives
%   in a repository outside this work. The migrator emits the term with an
%   EMPTY node for that reason and says so. The test above buys the safety
%   without waiting for the vocabulary.
%
%   See also: ndi.vintage.elementSubjectDocs, ndi.vintage.map.

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
