classdef ido < did.ido
    % ndi.ido - identifier object class for ndi
    %
    % This class creates and retrieves unique identifiers.  The identifier is a hexadecimal string
    %  based on both the current date/time and a random number. When identifiers are sorted in
    %  alphabetical order, they are also sorted in the order of time of creation.
    %
    % **Example**:
    %   i = ndi.ido();
    %   id = i.id(), % view the id that was created
    %
end
