function tf = isOntologyLabelClass(className)
%ISONTOLOGYLABELCLASS True when CLASSNAME names a v1 ontology-label document.
%
%   TF = ndi.migrate.internal.isOntologyLabelClass(CLASSNAME) is true for both
%   spellings the second pass can receive from pass 1:
%
%     'ontologyLabel'    the v1 class name (NDI template
%                        database_documents/data/ontologyLabel.json), which
%                        reaches the second pass when DID-matlab carries the
%                        document as raw v1;
%     'ontology_label'   the renamed spelling DID-matlab's universalRenames
%                        gives it when it passes the document through.
%
%   This is the ONE place the second pass decides "is this a label document",
%   so a change in which spelling DID-matlab hands over is a change here only.
%   did-schema CLAUDE.md, "Changes the siblings must follow land in the
%   siblings first": NDI accepts both before DID-matlab switches the label to
%   raw v1.
%
%   CLASSNAME may be a char vector or a string scalar; anything else is false.
%
%   See also ndi.migrate.internal.ontologyLabelSubjects.

if isstring(className) && isscalar(className)
    className = char(className);
end
tf = ischar(className) && any(strcmp(className, {'ontology_label', 'ontologyLabel'}));
end
