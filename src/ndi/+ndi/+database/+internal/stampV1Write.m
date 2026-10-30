function [doc, how] = stampV1Write(doc, templates)
%STAMPV1WRITE Stamp a v1-template document 'did_v1' and check it against NDI's v1 template.
%
%   [DOC, HOW] = ndi.database.internal.stampV1Write(DOC)
%   [DOC, HOW] = ndi.database.internal.stampV1Write(DOC, TEMPLATES)
%
%   DOC is a did2.document about to be written into a V2 (did2) database
%   through ndi.database.implementations.database.did2sqlite. TEMPLATES is
%   a did2.schema.v1Templates index; by default
%   ndi.database.internal.v1TemplateIndex() (NDI's own v1 templates, with
%   any NDIcalc calculator templates on the path).
%
%   WHICH DOCUMENTS. Told apart by the document's own stamp,
%   document_class.schema_version, with DID's stamp tests:
%     * UNSTAMPED (did2.schema.isV1Stamp true, and false with 'Explicit'):
%       a v1-template document built by one of NDI's v1 writers (the spike
%       sorter, the spike extractor, element, probe location, openMINDS,
%       the syncgraph, ...). It is checked against NDI's v1 template for its
%       class (did2.validate.v1Document) and, when it passes, stamped
%       'did_v1' exactly as ndi.migrate.internal.carryUnchangedAsV1 stamps a
%       carried document (document_class.schema_version = 'did_v1', nothing
%       else changed). did2.database.sqlitedb then stores it without V_eta
%       validation and counts it (report.v1_not_validated), so it is no
%       longer validated against the V_eta class of the same name.
%       HOW = 'v1_stamped'.
%     * ANY STAMP (a V2 stamp 'did_v2', an explicit 'did_v1', or any other
%       name): returned unchanged. A V2 document is validated as V2 by
%       did2.database.sqlitedb, as before; a document already stamped
%       'did_v1' is stored as before (it was stamped by the migration, which
%       ran its own template check). HOW = 'unchanged'.
%
%   ERRORS (nothing is written: did2sqlite checks the whole list before it
%   adds any of it):
%     NDI:did2sqlite:v1TemplateMismatch  the template check found problems;
%                                        the message lists them
%     NDI:did2sqlite:v1TemplatesNotFound no NDI v1 template could be read,
%                                        so the document cannot be checked
%                                        (NOT CHECKED is never stored as
%                                        checked)
%
%   WHY. Decided by Jess Haley, 2026-10-29 [v1 writes into a V2 session]
%   (did-schema schemas/V_eta_go_forward_class_audit.md): "for now, a
%   v1-template document NDI writes into a session with a V2 database is
%   stamped did_v1 and checked against NDI's own v1 template, as a carried
%   document is, so no retire file is needed for it; the end state is that
%   every NDI writer writes V2 documents". The stamp is [document stamps]
%   (2026-10-25); the template check is [carried v1 validates against NDI
%   templates] (2026-10-27), DID-matlab did2.validate.v1Document.
%
%   See also ndi.database.internal.v1TemplateIndex,
%            ndi.database.implementations.database.did2sqlite,
%            ndi.migrate.internal.carryUnchangedAsV1,
%            did2.schema.isV1Stamp, did2.validate.v1Document.

arguments
    doc (1,1) did2.document
    templates = []
end

how = 'unchanged';
s = doc.toStruct();
if ~did2.schema.isV1Stamp(s) || did2.schema.isV1Stamp(s, 'Explicit', true)
    return;   % stamped: V2, an explicit did_v1, or another name -- as before
end

if isempty(templates)
    templates = ndi.database.internal.v1TemplateIndex();
end
r = did2.validate.v1Document(s, templates);
id = '';
if isfield(s, 'base') && isstruct(s.base) && isfield(s.base, 'id')
    id = char(s.base.id);
end
if ~r.checked
    error('NDI:did2sqlite:v1TemplatesNotFound', ...
        ['Document %s (class "%s") is a v1 document written into a V2 ' ...
         'database, and NDI''s v1 templates could not be read (looked in ' ...
         '"%s"), so it cannot be checked. It is refused rather than stored ' ...
         'unchecked.'], id, r.class_name, char(templates.root));
end
if ~r.ok
    error('NDI:did2sqlite:v1TemplateMismatch', ...
        ['Document %s (class "%s") is a v1 document written into a V2 ' ...
         'database and does not match NDI''s v1 template for its class ' ...
         '(%d problem(s)): %s'], id, r.class_name, numel(r.problems), ...
        strjoin(r.problems, '; '));
end
s.document_class.schema_version = 'did_v1';
doc = did2.document(s);
how = 'v1_stamped';
end
