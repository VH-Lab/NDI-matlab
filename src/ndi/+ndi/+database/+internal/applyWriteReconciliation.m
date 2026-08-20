function ndoc = applyWriteReconciliation(ndoc)
%APPLYWRITERECONCILIATION Reconcile a doc to V_delta canonical before storage.
%
%   NDOC = ndi.database.internal.applyWriteReconciliation(NDOC) is the
%   write-path counterpart to ndi.database.internal.applyReadNormalization.
%   It takes an ndi.document whose body may carry did_v1 legacy aliases
%   (added by ndi.compat.augmentRead on read), reconciles any legacy
%   edits back into the V_delta canonical paths, and strips the legacy
%   fields so only V_delta hits the database.
%
%   The reconciliation work itself lives in ndi.compat.reconcileWrite
%   (data-driven by ndi.compat.fieldAliases); this helper just bridges
%   the ndi.document <-> body interface and produces a new
%   ndi.document via the augmentation-bypass factory
%   ndi.document.fromBody.
%
%   ndi.database.add calls this helper before invoking the backend's
%   do_add, so every concrete ndi.database subclass benefits without
%   per-backend wiring.
%
%   Inputs:
%     NDOC  ndi.document or cell array of ndi.document - the document(s)
%           to write. ndi.session.database_add passes a cell array
%           through ndi.database.add, so the helper handles both.
%
%   Outputs:
%     NDOC  same shape as input - reconciled document(s).
%
%   See also: ndi.compat.reconcileWrite, ndi.compat.augmentRead,
%             ndi.compat.fieldAliases, ndi.database/add,
%             ndi.document.fromBody.

    if iscell(ndoc)
        for k = 1:numel(ndoc)
            ndoc{k} = ndi.database.internal.applyWriteReconciliation(ndoc{k});
        end
        return;
    end

    if ~isa(ndoc, 'ndi.document')
        error('NDI:database:reconcileBadInput', ...
            ['ndi.database.internal.applyWriteReconciliation expects ' ...
             'an ndi.document or cell array of them (got "%s").'], ...
            class(ndoc));
    end

    body = ndi.compat.reconcileWrite(ndoc.document_properties);
    ndoc = ndi.document.fromBody(body);
end
