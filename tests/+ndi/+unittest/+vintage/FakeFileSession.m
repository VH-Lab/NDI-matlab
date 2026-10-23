classdef FakeFileSession
%FAKEFILESESSION The two session calls ndi.database.fun.extract_docs_files
%   makes, and nothing more. DATABASE_SEARCH returns the documents it was
%   built with; DATABASE_EXISTBINARYDOC answers from a name -> path map,
%   [false, ''] for any other name -- so a test sees exactly which member
%   names the walker asked for by which ones it recorded.

    properties
        Docs
        Files
    end

    methods
        function obj = FakeFileSession(docs, files)
            arguments
                docs
                files containers.Map
            end
            obj.Docs = docs;
            obj.Files = files;
        end

        function d = database_search(obj, query)
            arguments
                obj (1,1) ndi.unittest.vintage.FakeFileSession
                query %#ok<INUSA> every search returns all the documents
            end
            d = obj.Docs;
        end

        function [tf, p] = database_existbinarydoc(obj, docId, name)
            arguments
                obj (1,1) ndi.unittest.vintage.FakeFileSession
                docId %#ok<INUSA> answered by file name alone
                name {mustBeText}
            end
            tf = isKey(obj.Files, name);
            p = '';
            if tf
                p = obj.Files(name);
            end
        end
    end
end
