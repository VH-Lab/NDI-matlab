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
%   here: did2.schema.isV2Stamp (DID-matlab's one list of V2 stamps). A
%   version that is not a V2 stamp is v1 (base 1), which is what every
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

% did2.schema.isV2Stamp reads the V2 stamps, 'did_v2' and (only until the
% writers stamp 'did_v2') 'V_eta' (Decided by Jess Haley, 2026-10-25
% [document stamps], [V_eta stamp not accepted]).
if did2.schema.isV2Stamp(props)
    base = 0;
end
end
