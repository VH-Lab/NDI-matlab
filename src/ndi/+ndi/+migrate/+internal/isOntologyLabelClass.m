function tf = isOntologyLabelClass(className)
%ISONTOLOGYLABELCLASS True when CLASSNAME names a v1 ontology-label document.
%
%   TF = ndi.migrate.internal.isOntologyLabelClass(CLASSNAME) is true for
%   'ontologyLabel', the v1 class name (NDI template
%   database_documents/data/ontologyLabel.json), which is how pass 1 hands a
%   label to the second pass. DID-matlab #351 deleted
%   did2.convert.universalRenames, so the renamed spelling 'ontology_label' no
%   longer reaches the second pass and is not a label ([migrators read raw
%   v1]; [ndi_document read as base], [rename clashes are malformed], Jess
%   Haley, did-schema did_v2_go_forward_class_audit.md).
%
%   This is the ONE place the second pass decides "is this a label document".
%
%   CLASSNAME may be a char vector or a string scalar; anything else is false.
%
%   See also ndi.migrate.internal.ontologyLabelSubjects.

if isstring(className) && isscalar(className)
    className = char(className);
end
tf = ischar(className) && strcmp(className, 'ontologyLabel');
end
