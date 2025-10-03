function [creationDate] = dateCreated(fileName)
%DATECREATED Gets the creation date of a file on Windows, macOS, or Linux.
%
% SYNTAX:
%   creationDate = dateCreated(fileName)
%
% DESCRIPTION:
%   dateCreated(fileName) returns the creation (birth) date of the specified
%   file as a datetime object. This function is cross-platform compatible,
%   calling the appropriate native system command ('dir /T:C' on Windows,
%   'stat' on macOS and Linux) to retrieve the date. It is primarily
%   useful as a fallback for MATLAB versions older than R2014b, where file
%   creation date was not directly accessible.
%
% INPUTS:
%   fileName - A string or character vector specifying the path to the
%              file.
%
% OUTPUTS:
%   creationDate - A datetime object representing the file's creation
%                  time. Returns NaT (Not-a-Time) if the date cannot
%                  be determined or the file is not found.

if ispc
    % The command 'dir /T:C' lists files using their creation time.
    % We pipe it to 'findstr' to isolate the line with our file.
    command = sprintf('dir /T:C "%s" | findstr "%s"', fileName, fileName);
    [status, cmdout] = system(command);
    
    if status == 0 && ~isempty(cmdout)
        tok = regexp(cmdout, '(\d{2}/\d{2}/\d{4}\s+\d{1,2}:\d{2}\s+[AP]M)', 'tokens');
        if ~isempty(tok)
            dateString = tok{1}{1};
            % Convert the extracted string to a datetime object
            creationDate = datetime(dateString, 'InputFormat', 'MM/dd/yyyy hh:mm a');
        else
            creationDate = NaT; % Return a "Not-a-Time" datetime object
        end
    else
        creationDate = NaT;
    end
else
    if ismac
        command = sprintf('stat -f "%%SB" "%s"', fileName);
        formatSpec = 'MMM d HH:mm:ss yyyy'; % Format for macOS
    else
        command = sprintf('stat -c %%w "%s"', fileName);
        formatSpec = 'yyyy-MM-dd HH:mm:ss.SSSSSSSSS Z'; % Format for Linux
    end
    
    [status, cmdout] = system(command);
    
    if status == 0 && ~isempty(cmdout)
        dateString = strtrim(cmdout);
        % Convert the output string to a datetime object
        creationDate = datetime(dateString, 'InputFormat', formatSpec);
    else
        creationDate = NaT; % Return "Not-a-Time" on failure
    end
end

end