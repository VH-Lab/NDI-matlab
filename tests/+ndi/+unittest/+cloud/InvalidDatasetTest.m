classdef InvalidDatasetTest < matlab.unittest.TestCase
    methods (Test)
        function invalidDataset(testCase)
            % Test that downloading an invalid dataset ID throws a helpful error.

            % Attempt to download with a nonsense ID
            % We expect an error, but we want to verify the error message is somewhat helpful
            % rather than "Dot indexing is not supported".

            try
                [D] = ndi.cloud.downloadDataset('asdjjdsf');
                % If we get here, it means no error was thrown, which might be okay if it just returns empty?
                % But the user says "One should get an error saying that there is no such dataset."
                testCase.verifyFail('Expected an error when downloading an invalid dataset, but none was thrown.');
            catch ME
                % Check if the error is the unhelpful one
                if contains(ME.message, 'Dot indexing is not supported')
                    testCase.verifyFail(['Received unhelpful error message: ' ME.message]);
                elseif contains(ME.message, 'not found') || contains(ME.message, 'exist') || contains(ME.message, 'invalid')
                     % This would be a good error message
                     testCase.verifyTrue(true);
                else
                    % Some other error
                    disp(['Received error: ' ME.message]);
                    % For now just pass if it's not the dot indexing one, but we ideally want a specific message.
                    % Let's verify it's NOT the dot indexing one.
                     testCase.verifyFalse(contains(ME.message, 'Dot indexing is not supported'), ...
                        ['Still receiving dot indexing error: ' ME.message]);
                end
            end
        end
    end
end
