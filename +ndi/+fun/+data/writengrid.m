function [ ] = writengrid(x,filePath,dataType)
%WRITENGRID - Write an n-dimensional matrix to a binary file.
%
%   Writes the n-dimensional matrix X to a binary file with specified data 
%   type. The binary file is written in little-endian format to ensure 
%   cross-platform compatibility.
%
%   Syntax:
%       WRITENGRID(x, filePath)
%       WRITENGRID(x, filePath, dataType)
%
%   Input Arguments:
%       x        - n-dimensional matrix.
%                  The data to be written to the binary file.
%       filePath - Character vector specifying the full path and filename
%                  of the output binary file.
%       dataType - (Optional) Character vector specifying the data type of the
%                  elements in X. Defaults to 'double' if not provided.
%                  Valid data types include 'double', 'single', 'int8', 'uint8',
%                  'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64',
%                  etc.
%
%   Error Handling:
%       - 'WRITENGRID:unknownDataType': If the dataType provided is not 
%           recognized by fwrite a warning is issued.
%       - 'WRITENGRID:invalidFilePath': If the specified filePath cannot be
%           opened for writing.
%
%   See also: READNGRID

    arguments
        x
        filePath (1,:) char {mustBeTextScalar}
        dataType (1,:) char {mustBeTextScalar} = 'double'
    end

    % Check if the data type is valid.
    validDataTypes = {'double', 'single', 'int8', 'uint8', 'int16', 'uint16', ...
                      'int32', 'uint32', 'int64', 'uint64', 'char', 'logical'};

    if ~any(strcmp(dataType, validDataTypes))
        warning('WRITENGRID:unknownDataType',['Data type ''' dataType ...
            ''' is not a standard MATLAB data type. ' ...
            'fwrite may interpret it incorrectly. Proceed with caution.']);
    end

    % Write a binary file
    fid = fopen(filePath,'w','ieee-le'); % force little endian for all OS
    if fid < 0
        error('WRITENGRID:invalidFilePath',['Could not open file ''' ...
            filePath ''' for writing. ' ...
            'Ensure the path is correct and you have write permissions.']);
    end

    % Attempt to write the data to the file.
    try
        fwrite(fid, x, dataType);
    catch ME
        fclose(fid);
        rethrow(ME); % Re-throw the original error.
    end

    % Close the file.
    fclose(fid);
end