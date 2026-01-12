classdef DatasetSessionIdFromDocsTest < matlab.unittest.TestCase

    methods (Test)
        function testBasicFunctionality(testCase)
            % Test with 1 session and 0 dataset_session_info

            % document_class should be a struct with class_name
            d1 = struct('document_class', struct('class_name', 'session'), ...
                        'base', struct('session_id', 'session1', 'id', 'id1', 'datestamp', ''));
            doc1 = ndi.document(d1);

            sessionId = ndi.cloud.sync.internal.datasetSessionIdFromDocs({doc1});
            testCase.verifyEqual(sessionId, 'session1');
        end

        function testWithConfirmedSession(testCase)
            % Test with 2 sessions and 1 dataset_session_info that confirms one
            d1 = struct('document_class', struct('class_name', 'session'), ...
                        'base', struct('session_id', 'session1', 'id', 'id1', 'datestamp', ''));
            doc1 = ndi.document(d1);

            d2 = struct('document_class', struct('class_name', 'session'), ...
                        'base', struct('session_id', 'session2', 'id', 'id2', 'datestamp', ''));
            doc2 = ndi.document(d2);

            % dataset_session_info document
            % It has a struct array at doc.document_properties.dataset_session_info.dataset_session_info
            ds_info_struct = struct('session_id', 'session1');
            d3 = struct('document_class', struct('class_name', 'dataset_session_info'), ...
                        'base', struct('id', 'id3', 'datestamp', ''), ...
                        'dataset_session_info', struct('dataset_session_info', ds_info_struct));
            doc3 = ndi.document(d3);

            sessionId = ndi.cloud.sync.internal.datasetSessionIdFromDocs({doc1, doc2, doc3});
            testCase.verifyEqual(sessionId, 'session2');
        end

        function testMultipleDatasetSessionInfoError(testCase)
            % Should error if > 1 dataset_session_info doc
             d3 = struct('document_class', struct('class_name', 'dataset_session_info'), ...
                        'base', struct('id', 'id3', 'datestamp', ''), ...
                        'dataset_session_info', struct('dataset_session_info', struct('session_id', 's1')));
            doc3 = ndi.document(d3);

            testCase.verifyError(@() ndi.cloud.sync.internal.datasetSessionIdFromDocs({doc3, doc3}), ...
                'ndi:cloud:sync:internal:datasetSessionIdFromDocs:tooManyDatasetSessionInfo');
        end

        function testNoUniqueSessionError(testCase)
            % Should error if 0 sessions left
             d1 = struct('document_class', struct('class_name', 'session'), ...
                        'base', struct('session_id', 'session1', 'id', 'id1', 'datestamp', ''));
            doc1 = ndi.document(d1);

            ds_info_struct = struct('session_id', 'session1');
            d3 = struct('document_class', struct('class_name', 'dataset_session_info'), ...
                        'base', struct('id', 'id3', 'datestamp', ''), ...
                        'dataset_session_info', struct('dataset_session_info', ds_info_struct));
            doc3 = ndi.document(d3);

            testCase.verifyError(@() ndi.cloud.sync.internal.datasetSessionIdFromDocs({doc1, doc3}), ...
                'ndi:cloud:sync:internal:datasetSessionIdFromDocs:invalidSessionCount');
        end

        function testMultipleRemainingSessionsError(testCase)
            % Should error if > 1 sessions left
             d1 = struct('document_class', struct('class_name', 'session'), ...
                        'base', struct('session_id', 'session1', 'id', 'id1', 'datestamp', ''));
            doc1 = ndi.document(d1);

             d2 = struct('document_class', struct('class_name', 'session'), ...
                        'base', struct('session_id', 'session2', 'id', 'id2', 'datestamp', ''));
            doc2 = ndi.document(d2);

            testCase.verifyError(@() ndi.cloud.sync.internal.datasetSessionIdFromDocs({doc1, doc2}), ...
                'ndi:cloud:sync:internal:datasetSessionIdFromDocs:invalidSessionCount');
        end
    end
end
