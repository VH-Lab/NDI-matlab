classdef documentservice
% ndi.documentservice - a class of methods that allows objects to interact with ndi.document objects
%
    properties (SetAccess=protected, GetAccess=public)

    end; % properties

    methods
        function ndi_documentservice_obj = documentservice()
            %ndi.documentservice - create an ndi.documentservice object, which is just an abstract class
            %
            % NDI_DOCUMENTSERVICE_OBJ = ndi.documentservice();
            %
                
        end; % ndi.documentservice()

        function ndi_document_obj = newdocument(ndi_documentservice_obj)
            % NEWDOCUMENT - create a new ndi.document based on information in this object
            %
            % NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_DOCUMENTSERVICE_OBJ)
            %
            % Create a new ndi.document based on information in this class.
            %
            % The base ndi.documentservice class returns empty.
            %
                ndi_document_obj = [];
        end; % newdocument

        function sq = searchquery(ndi_documentservice_obj)
            % SEARCHQUERY - create a search query to find this object as an ndi.document
            %
            % SQ = SEARCHQUERY(NDI_DOCUMENTSERVICE_OBJ)
            %
            % Return a search query that can be used to find this object's representation as an
            % ndi.document.
            %
            % The base class ndi.documentservice just returns empty.
                sq = [];
        end; % searchquery
    end; 
end


