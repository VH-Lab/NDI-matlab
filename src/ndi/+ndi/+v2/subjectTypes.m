function t = subjectTypes()
%SUBJECTTYPES The entity types that are subjects: what `isa subject` finds.
%
%   T = ndi.v2.subjectTypes() is {'organism', 'culture', 'tissue', 'cell',
%   'group'}: the biological types, which a v1 `subject` document always
%   was. A device (a probe, a camera) and a material (a plate) are entities
%   of the experiment too, but not subjects, so ndi.query('', 'isa',
%   'subject') leaves them out (Jess Haley,
%   2026-10-08). A subject document with no type (v1) is a subject.
%
%   See also ndi.query, ndi.v2.entityTypesFor.

% NDI's handles, compared through ndi.v2.vocabHandle / vocabQuery by node
% first: `culture` is OBI:0001876, stored `culture` or "cell culture"
% ([culture renamed cell culture], Jess Haley, 2026-11-10)
t = {'organism', 'culture', 'tissue', 'cell', 'group'};
end
