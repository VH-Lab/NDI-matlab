function [outputArg1,outputArg2] = check_metadata_inputs(varargin)
%CHECK_METADATA_INPUTS Summary of this function goes here
%   Detailed explanation goes here
did.datastructures.assign(varargin{:});
msg = cell(1,3);
state = 1;



%% DigitalIdentifier
digitalIdentifierPattern = '^https://ror.org/0([0-9]|[^ILO]|[a-z]){6}[0-9]{2}$';
for i = 1:numAuthors
    match = regexp(digitalIdentifier{i}, digitalIdentifierPattern, 'match');
    if isempty(match)
        err.digitalIdentifier = "Digital Identifier is invalid.";
        err.numAuthors = i;
        msg{2} = "Wrong input for step 2";
        state = 0;
    end
end

%% email
emailPattern = "(?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/";

%% 


