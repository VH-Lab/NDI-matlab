classdef ndi_documentservice
% NDI_DOCUMENTSERVICE - a class of methods that allows objects to interact with NDI_DOCUMENT objects
%
	properties (SetAccess=protected, GetAccess=public)

	end; % properties

	methods
		function ndi_documentservice_obj = ndi_documentservice()
			%NDI_DOCUMENTSERVICE - create an NDI_DOCUMENTSERVICE object, which is just an abstract class
			%
			% NDI_DOCUMENTSERVICE_OBJ = NDI_DOCUMENTSERVICE();
			%
				
		end; % ndi_documentservice()

		function ndi_document_obj = newdocument(ndi_documentservice_obj)
			% NEWDOCUMENT - create a new NDI_DOCUMENT based on information in this object
			%
			% NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_DOCUMENTSERVICE_OBJ)
			%
			% Create a new NDI_DOCUMENT based on information in this class.
			%
			% The base NDI_DOCUMENTSERVICE class returns empty.
			%
				ndi_document_obj = [];
		end; % newdocument

		function sq = searchquery(ndi_documentservice_obj)
			% SEARCHQUERY - create a search query to find this object as an NDI_DOCUMENT
			%
			% SQ = SEARCHQUERY(NDI_DOCUMENTSERVICE_OBJ)
			%
			% Return a search query that can be used to find this object's representation as an
			% NDI_DOCUMENT.
			%
			% The base class NDI_DOCUMENTSERVICE just returns empty.
				sq = [];
		end; % searchquery
	end; 
end


