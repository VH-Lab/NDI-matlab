function ndiDocumentObj = applyReadNormalization(rawDoc)
%APPLYREADNORMALIZATION Normalise a stored document body to V_delta on read.
%
%   NDIDOCUMENTOBJ = ndi.database.internal.applyReadNormalization(RAWDOC)
%   routes RAWDOC through did2.convert.v1_to_v2 so that any v1-shaped
%   body read from a concrete ndi.database backend is returned as a
%   V_delta-shaped ndi.document. V_delta bodies short-circuit the
%   converter's idempotency check (see did2.convert.v1_to_v2), so
%   re-reads of already-V_delta documents stay cheap.
%
%   Concrete ndi.database subclasses call this helper from their
%   do_read / do_search implementations so the abstract ndi.database
%   API stays byte-identical: callers above the abstraction (session,
%   dataset, queries) never see the on-wire shape difference between
%   v1 and V_delta. Schema migration lives at the storage boundary,
%   not in session.m or dataset.m.
%
%   RAWDOC may be:
%       - a struct                (the body itself),
%       - a did.document          (its document_properties is used),
%       - a did2.document         (its toStruct() is used),
%       - an ndi.document         (its document_properties is used),
%       - empty []                (returns []).
%
%   Errors:
%       NDI:database:normalizeBadInput  - RAWDOC is not a recognised
%                                         document/body type.
%       NDI:database:normalizeFailed    - did2.convert.v1_to_v2
%                                         quarantined the body and no
%                                         migrated document was produced.
%
%   See also: did2.convert.v1_to_v2, ndi.database,
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
        body = rawDoc.document_properties;
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
