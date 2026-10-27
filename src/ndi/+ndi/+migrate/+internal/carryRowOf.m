function row = carryRowOf(reason)
%CARRYROWOF The carry register row a second-pass reason cites, or ''.
%
%   ROW = ndi.migrate.internal.carryRowOf(REASON) returns the row id
%   ('carry-NNN') of the first `[carry-NNN]` tag in REASON, or '' when REASON
%   cites none.
%
%   Decided by Jess Haley, 2026-10-26 [carry register] (did-schema
%   V_eta_go_forward_class_audit.md): every reason the generic migration
%   carries a v1 document whole as v1 is a row of ONE register, did-schema
%   schemas/V_eta_carry_register.json, and every carry note cites its row.
%   NDI's second-pass reasons cite it with a `[carry-NNN]` tag placed before
%   the reason it covers, as DID-matlab's carry notes do (DID-matlab
%   tools/check_carry_citations.py); the test
%   ndi.unittest.migrate.TestCarryRegisterCitations checks that every tag
%   names a row of the register.
%
%   See also ndi.migrate.internal.carryUnchangedAsV1.

arguments
    reason = ''
end

row = '';
if isstring(reason) && isscalar(reason)
    reason = char(reason);
end
if ~ischar(reason) || isempty(reason)
    return;
end
tok = regexp(reason, '\[(carry-\d{3})\]', 'tokens', 'once');
if ~isempty(tok)
    row = tok{1};
end
end
