function tf = hasWildcardOperator()
%HASWILDCARDOPERATOR Can a query use did2's `wildcard` operator.
%
%   TF = ndi.v2.hasWildcardOperator() is true when both did.query (which
%   ndi.query is) and did2.query accept the operator (DID-matlab #218). A
%   search that cannot send a wildcard leaves that part to the recheck in
%   MATLAB: the same answer, more documents read. Checked once per session.

persistent known
if isempty(known)
    try
        did.query('a', 'wildcard', 'x');
        did2.query.searchstruct('a', 'wildcard', 'x');
        known = true;
    catch
        known = false;
    end
end
tf = known;
end
