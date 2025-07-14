function [docs] = finddocs_elementEpochType(S,elementID,epochID,documentType)
%FINDDOCS_ELEMENTEPOCHTYPE Searches for documents in the NDI database.
%
%   Syntax:
%       docs = FINDDOCS_ELEMENTEPOCHTYPE(sessionObj,elementID,epochID,documentType)
%
%   Description:
%       This function constructs database queries using `ndi.query` based
%       on the provided session object, element ID, epoch ID, and document
%       type. It then combines these queries and executes a search to 
%       retrieve matching documents.
%
%   Input Arguments:
%       S (ndi.session | ndi.dataset object)
%       elementID (char vector | string scalar) - The ndi.element id
%       epochID (char vector | string scalar) - The ndi.element epoch_id
%       documentType (char vector | string scalar) - The type of document
%           to search for (e.g., 'spectrogram').
%
%   Output Arguments:
%       docs - The document(s) matching the search criteria.

arguments
    S (1,1) {mustBeA(S,{'ndi.session','ndi.dataset'})} 
    elementID (1,:) char {mustBeTextScalar}
    epochID (1,:) char {mustBeTextScalar}
    documentType (1,:) char {mustBeTextScalar}
end

q1 = ndi.query('','isa',documentType);
q2 = ndi.query('','depends_on','element_id',elementID);
q3 = ndi.query('epochid.epochid','exact_string',epochID);
docs = S.database_search(q1&q2&q3);

end