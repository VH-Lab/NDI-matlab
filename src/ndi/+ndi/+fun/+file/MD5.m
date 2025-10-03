function checksum = MD5(fileName)
%MD5 Calculates the MD5 checksum of a file across different operating systems.
%
% SYNTAX:
%   checksum = MD5(fileName)
%
% DESCRIPTION:
%   MD5(fileName) calculates the 32-character hexadecimal MD5 checksum for
%   the specified file. This function is cross-platform compatible and
%   works on Windows, macOS, and Linux by calling the appropriate native
%   system command ('CertUtil', 'md5', or 'md5sum').
%
% INPUTS:
%   fileName - A string or character vector specifying the path to the
%              file.
%
% OUTPUTS:
%   checksum - A 1x32 character vector containing the lowercase MD5 hash.

% 1. Check if the file exists
if ~isfile(fileName)
    error('File not found: %s', fileName);
end

% 2. Execute the correct command based on the operating system
if ispc % Windows
    command = sprintf('CertUtil -hashfile "%s" MD5', fileName);
    [status, cmdout] = system(command);
    
    if status == 0
        % The checksum is on the second line of the output
        lines = strsplit(cmdout, '\n');
        % Remove spaces and trim the line
        checksum = strrep(lines{2}, ' ', '');
        checksum = strtrim(checksum);
    end
    
elseif isunix % macOS or Linux
    if ismac % macOS
        command = sprintf('md5 "%s"', fileName);
        [status, cmdout] = system(command);
        if status == 0
            % Parse "MD5 (file) = checksum"
            checksum = regexp(strtrim(cmdout), '[a-f0-9]{32}$', 'match', 'once');
        end
    else % Assumes Linux
        command = sprintf('md5sum "%s"', fileName);
        [status, cmdout] = system(command);
        if status == 0
            % Parse "checksum  file"
            checksum = regexp(strtrim(cmdout), '^[a-f0-9]{32}', 'match', 'once');
        end
    end
    
else
    error('Unsupported operating system.');
end

% 3. Check for errors during command execution
if status ~= 0
    error('Failed to compute MD5 checksum. Command output:\n%s', cmdout);
end

end