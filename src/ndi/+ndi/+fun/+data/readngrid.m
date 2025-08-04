function x = readngrid(fileName_or_fileObj, dataSize, dataType)
%READNGRID - Read an n-dimensional matrix from a binary file.
%
%   Reads an n-dimensional matrix from a binary file, given the file path,
%   the size of the matrix, and the data type of its elements.
%
%   Syntax:
%       x = READNGRID(fileName_or_fileObj, dataSize)
%       x = READNGRID(fileName_or_fileObj, dataSize, dataType)
%
%   Input Arguments:
%       fileName_or_fileObj - Character vector specifying the full path and
%                  filename of the input binary file OR an object of type
%                  vlt.file.fileobj.
%       dataSize - Numeric vector specifying the dimensions of the 
%                  n-dimensional matrix to be read (e.g., [100, 100, 5]).
%       dataType - (Optional) Character vector specifying the data type of 
%                  the elements in the binary file. Defaults to 'double' if
%                   not provided. Valid data types include 'double', 
%                  'single', 'int8', 'uint8', 'int16', 'uint16', 'int32', 
%                   'uint32', 'int64', 'uint64', etc.
%
%   Output Arguments:
%       x        - n-dimensional matrix read from the binary file.
%
%   Error Handling:
%       - 'READNGRID:unknownDataType': If the dataType provided is not 
%           recognized by fread a warning is issued.
%       - 'READNGRID:invalidFilePath': If the specified filePath cannot be
%           opened for reading.
%       - 'READNGRID:incorrectDataSize': If the number of elements read by
%           fread does not match the expected number based on dataSize a
%           warning is issued.
%
%   See also: WRITENGRID.

    arguments
        fileName_or_fileObj (1,:) {mustBeA(fileName_or_fileObj,{'char', 'did.file.readonly_fileobj'})}
        dataSize (1,:) double {mustBePositive, mustBeInteger}
        dataType (1,:) char {mustBeTextScalar} = 'double'
    end

    % Check if the data type is valid.
    validDataTypes = {'double', 'single', 'int8', 'uint8', 'int16', 'uint16', ...
                      'int32', 'uint32', 'int64', 'uint64', 'char', 'logical'};

    if strcmp(dataType, 'ubit1')
        % skip warning
    elseif ~any(strcmp(dataType, validDataTypes))
        warning('READNGRID:unknownDataType',['Data type ''' dataType ...
            ''' is not a standard MATLAB data type. ' ...
            'fread may interpret it incorrectly. Proceed with caution.']);
    end

    % Attempt to open the file for reading.
    fid = fopen(fileName_or_fileObj, 'r', 'ieee-le'); % Force little-endian

    % Check if the file was opened successfully.
    if fid < 0
        error('READNGRID:invalidFilePath',...
            ['Could not open file ''' fileName_or_fileObj ''' for reading. ' ...
            'Ensure the path is correct and the file exists.']);
    end

    % Attempt to read the data from the file.
    try
        x = fread(fid, dataSize, dataType);

        % Check if the number of elements read matches the expected size.
        expectedNumElements = prod(dataSize);
        actualNumElements = numel(x);
        if actualNumElements ~= expectedNumElements
            warning('READNGRID:incorrectDataSize',['Number of elements read (' ...
                num2str(actualNumElements) ') does not match ' ...
                'the expected number (' num2str(expectedNumElements) '). ' ...
                'Check the dataSize argument.']);
        end
    catch ME
        fclose(fid);
        rethrow(ME); % Re-throw the original error.
    end

    % Close the file.
    fclose(fid);

end