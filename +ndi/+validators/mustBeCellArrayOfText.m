function mustBeCellArrayOfText(value)
    if ~iscell(value)
        eidType = 'Validator:notCell';
        msgType = 'Value must be a cell array.';
        throwAsCaller(MException(eidType,msgType));
    end
    if ~isempty(value) % Only iterate and check elements if the cell array is not empty
        for k = 1:numel(value)
            try
                mustBeText(value{k}); % This allows char vectors OR string scalars
            catch ME
                % Construct a new MException to provide more context
                errId = 'Validator:ElementNotText';
                errMsg = sprintf('Element %d of the cell array is not text (char vector or string scalar). It is a "%s".', k, class(value{k}));
                causeEx = MException(ME.identifier, ME.message);
                newEx =addCause(MException(errId, errMsg),causeEx);
                throwAsCaller(newEx);
            end
        end
    end
end

