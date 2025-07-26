function checkSubmission(filename, dataType, options)
% checkSubmission - Check status of a deposited submission
%
% Syntax:
%   checkSubmission(filename, dataType, options) checks the status (result) or
%   content of a metadata submission
%
% Input Arguments:
%   filename (string) - The name of the file to check submission status for
%   dataType (string) - The type of data to check, either "contents" or "result"
%   options (name-value pairs) - Optional name-value pairs
%     UseTestSystem (logical) - Flag indicating whether to use the test system
%
% NB: Requires crossref credentials being set as environment variables:
%   CROSSREF_USERNAME, CROSSREF_PASSWORD


    arguments
        filename (1,1) string
        dataType (1,1) string {mustBeMember(dataType, ["contents", "result"])} = "result";
        options.UseTestSystem (1,1) logical = false
    end

    crossref.checkSubmission(...
        "Filename", filename, ...
        "DataType", dataType, ...
        "UseTestSystem", options.UseTestSystem )
end

