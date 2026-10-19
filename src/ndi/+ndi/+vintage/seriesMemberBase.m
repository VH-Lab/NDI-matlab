function base = seriesMemberBase(doc)
%SERIESMEMBERBASE The number of a file series' FIRST member: 1 (v1) or 0 (V_eta).
%
%   BASE = ndi.vintage.seriesMemberBase(DOC)
%
%   DOC is an ndi.document, a did.document or a document_properties struct.
%   A file series names its members NAME_<number>. The numbering depends on
%   the DOCUMENT'S VINTAGE, never on a file name:
%     1  a v1 document (no document_class.schema_version, or one before
%        V_eta): NAME_1 is manifest slot 0. This is what NDI writes today
%        (makePyramid's chunk.bin_1.., the ingested epoch series).
%     0  a V_eta document: NAME_0 is slot 0 (DID-schema #73 item 17, kept by
%        Jess 2026-10-14), so a migrated lightsheet level's chunk.bin_k is
%        body_data_{k-1}.
%   The manifest is the same either way; only the names differ.
%
%   THE SAME RULE DID USES. When the DID-matlab on the path has
%   did.document/seriesMemberBase (DID-matlab 1a6bd9f), this asks it, so NDI
%   and DID can never disagree. An older DID-matlab (the V2 line NDI's
%   requirements.txt pins, which predates it) gets the same rule restated
%   here: rank document_class.schema_version with
%   did2.convert.schemaVersionRank when that exists, else compare it to
%   'V_eta'. A version neither recognises is v1 (base 1), which is what every
%   document written before V_eta is.
%
%   Callers that walk a series' slots (ndi.database.fun.extract_docs_files,
%   ndi.database.internal.list_binary_files) take member m (1-based slot) as
%   NAME_<m - 1 + BASE>.
%
%   See also: ndi.vintage.lightsheetChunkName, did.document/seriesMemberOf.

arguments
    doc
end

base = 1;
if isa(doc, 'did.document')
    if ismethod(doc, 'seriesMemberBase')
        base = double(doc.seriesMemberBase());
        return;
    end
    props = doc.document_properties;
elseif isstruct(doc)
    props = doc;
else
    return;
end

if ~isfield(props, 'document_class') || ~isstruct(props.document_class) ...
        || ~isfield(props.document_class, 'schema_version')
    return;
end
sv = props.document_class.schema_version;
if isstring(sv) && isscalar(sv), sv = char(sv); end
if ~ischar(sv) || isempty(sv)
    return;
end
if ~isempty(which('did2.convert.schemaVersionRank'))
    try
        [rank, known] = did2.convert.schemaVersionRank(sv);
        etaRank = did2.convert.schemaVersionRank('V_eta');
        if known && rank >= etaRank
            base = 0;
        end
        return;
    catch
        % fall through to the literal comparison
    end
end
if strcmp(sv, 'V_eta')
    base = 0;
end
end
