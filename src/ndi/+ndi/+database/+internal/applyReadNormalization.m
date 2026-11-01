function ndiDocumentObj = applyReadNormalization(rawDoc)
%APPLYREADNORMALIZATION Wrap a stored document body in an ndi.document on read.
%
%   NDIDOCUMENTOBJ = ndi.database.internal.applyReadNormalization(RAWDOC)
%   wraps a body read from a concrete ndi.database backend in an
%   ndi.document. It converts NOTHING between schema versions:
%
%     - a V2 document (document_class.schema_version a V2 stamp,
%       did2.schema.v2Stamps: 'did_v2'; 'V_eta' is not accepted; no v1
%       underscore markers) is read as V2. The only
%       change is did2.convert.ensureClassBlocks, which pads an empty
%       property block for any class of its V_eta superclass chain the
%       stored body lacks.
%     - every other body -- a did_v1 document (stamped 'did_v1' or not
%       stamped), or one carrying an older stamp -- is wrapped exactly as
%       stored.
%
%   NO READ-TIME CONVERSION. The one way from v1 to V2 is an explicit
%   migration, ndi.migrate.local (did2.convert.v1_to_v2 at 'V_eta' plus the
%   batch passes). A v1 dataset opened by NDI is read by the v1 code paths
%   in the shape it was written in -- the shape NDI's v1 readers
%   (ndi.vintage, ndi.app, stimulus and probe helpers) read.
%
%   What ndi.document's own constructor does to EVERY body is unchanged
%   and separate from this function: ndi.compat.normalizeDependsOn
%   (depends_on keys `id` / `value` -> `document_id`, as did.document's
%   constructor also does). The ndi.compat field aliases for
%   probe_location and treatment (augmentRead / reconcileWrite) are removed
%   (Decided by Jess Haley, 2026-10-23 [compat write layer removed]).
%
%   Concrete ndi.database subclasses call this helper from their
%   do_read / do_search implementations so the abstract ndi.database
%   API stays byte-identical: callers above the abstraction (session,
%   dataset, queries) only ever see ndi.document objects.
%
%   RAWDOC may be:
%       - a struct                (the body itself),
%       - a did.document          (its document_properties is used),
%       - a did2.document         (its toStruct() is used),
%       - an ndi.document         (passed through unchanged),
%       - empty []                (returns []).
%
%   Errors:
%       NDI:database:normalizeBadInput  - RAWDOC is not a recognised
%                                         document/body type.
%
%   See also: did2.convert.isAlreadyTarget, did2.convert.ensureClassBlocks,
%             ndi.migrate.local, ndi.compat.normalizeDependsOn, ndi.database,
%             ndi.database.implementations.database.didsqlite,
%             ndi.database.implementations.database.did2sqlite.

    if isempty(rawDoc)
        ndiDocumentObj = [];
        return;
    end

    if isa(rawDoc, 'did.document')
        body = rawDoc.document_properties;
    elseif isa(rawDoc, 'did2.document')
        body = rawDoc.toStruct();
    elseif isa(rawDoc, 'ndi.document')
        ndiDocumentObj = rawDoc;
        return;
    elseif isstruct(rawDoc) && isscalar(rawDoc)
        body = rawDoc;
    else
        error('NDI:database:normalizeBadInput', ...
            ['ndi.database.internal.applyReadNormalization expects a ' ...
             'struct, did.document, did2.document, or ndi.document ' ...
             '(got "%s").'], class(rawDoc));
    end

    if did2.convert.isAlreadyTarget(body, 'did_v2')
        body = did2.convert.ensureClassBlocks(body, []);
    end
    ndiDocumentObj = ndi.document(body);
end
