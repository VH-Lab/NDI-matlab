function [uniqueDocTypes] = getDocTypes(session)
%GETDOCTYPES Find all unique document types in an NDI session.
%   UNIQUE_DOC_TYPES = GETDOCTYPES(SESSION) queries the database of the
%   provided NDI session object to find all unique document types.
%
%   DESCRIPTION:
%   This function searches for all documents within the session, determines
%   the MATLAB class for each one and returns a sorted cell array of the 
%   unique class names found. It is a useful utility for exploring the 
%   contents of a session.
%
%   INPUTS:
%   session - An NDI session object, which must be of class 'ndi.session.dir'
%             or 'ndi.dataset.dir'.
%
%   OUTPUTS:
%   uniqueDocTypes - A cell array of character vectors, where each cell
%                    contains a unique document class name.
%
%   SEE ALSO:
%   ndi.session.dir, ndi.query, ndi.database.search, unique

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.dataset.dir'})}
end

% Retrieve all documents
query = ndi.query('','isa','base');
docs = session.database_search(query);

% Get document class
docClass = cellfun(@doc_class,docs,'UniformOutput',false);
uniqueDocTypes = unique(docClass);

end