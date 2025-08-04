function [docTypes,docCounts] = getDocTypes(session)
%GETDOCTYPES Find all unique document types and their counts in an NDI session.
%   [DOC_TYPES, DOC_COUNTS] = GETDOCTYPES(SESSION) queries the database of the
%   provided NDI session object to find all unique document types and their
%   corresponding counts.
%
%   DESCRIPTION:
%   This function searches for all documents within the session, determines
%   the MATLAB class for each one, and returns a sorted cell array of the
%   unique class names found, along with the number of occurrences for each.
%   It is a useful utility for exploring the contents and distribution of
%   documents within an NDI session.
%
%   INPUTS:
%   session - An NDI session object, which must be of class 'ndi.session.dir'
%             or 'ndi.dataset.dir'.
%
%   OUTPUTS:
%   docTypes - A cell array of character vectors, where each cell contains
%              a unique document class name. The unique class names are
%              returned in sorted order.
%   docCounts - A column vector of numerical counts, where each element
%               corresponds to the number of occurrences of the document
%               type at the same position in 'docTypes'.
%
%   SEE ALSO:
%   ndi.session, ndi.query, ndi.dataset, groupcounts

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.dataset.dir'})}
end

% Retrieve all documents
query = ndi.query('','isa','base');
docs = session.database_search(query);

% Get document class and counts
docClass = cellfun(@doc_class,docs,'UniformOutput',false)';
[docCounts,docTypes] = groupcounts(docClass);

end