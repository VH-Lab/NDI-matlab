function ndiDocumentObj = applyReadNormalization(rawDoc)
%APPLYREADNORMALIZATION Normalise a stored document body to V_delta on read.
%
%   NDIDOCUMENTOBJ = ndi.database.internal.applyReadNormalization(RAWDOC)
%   wraps a body read from a concrete ndi.database backend in an
%   ndi.document. RAWDOC is routed through did2.convert.v1_to_v2 so v1
%   bodies are returned as V_delta-shaped documents. V_delta bodies
%   short-circuit the converter's idempotency check, so re-reads of
%   already-V_delta documents stay cheap.
%
%   The in-memory ndi.document then carries the did_v1 legacy alias
%   paths injected by ndi.compat.augmentRead (issue #779), so callers
%   that still read legacy field names (e.g.,
%   ndi.database.fun.ndi_document2ndi_object,
%   ndi.daq.metadatareader, customer code reading
%   document_properties.probe_location.ontology_name) keep working
%   even though storage normalised to V_delta. The write-side mirror
%   lives in ndi.compat.reconcileWrite (issue #780); query-side path
%   translation lives in ndi.compat.translateQueryPaths (issue #781).
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
%       NDI:database:normalizeFailed    - did2.convert.v1_to_v2
%                                         quarantined the body so no
%                                         migrated document was produced.
%
%   See also: did2.convert.v1_to_v2, ndi.compat.augmentRead,
%             ndi.compat.reconcileWrite, ndi.compat.translateQueryPaths,
%             ndi.database,
%             ndi.database.implementations.database.didsqlite,
%             ndi.database.implementations.database.matlabdumbjsondb2.

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

    % Validate=false on the read path: the body was validated when it
    % was written, and re-validating every read for every doc burns
    % time on production workloads. The migrate command and the write
    % path remain responsible for validation.
    result = did2.convert.v1_to_v2(body, 'Validate', false);

    if isempty(result.migrated)
        if ~isempty(result.quarantine)
            reason = result.quarantine(1).reason;
            className = result.quarantine(1).class_name;
        else
            reason = '<no quarantine reason recorded>';
            className = '<unknown>';
        end
        error('NDI:database:normalizeFailed', ...
            ['did2.convert.v1_to_v2 failed to normalise a document ' ...
             'on read (class=%s): %s'], className, reason);
    end

    ndiDocumentObj = ndi.document(result.migrated{1}.toStruct());
end
