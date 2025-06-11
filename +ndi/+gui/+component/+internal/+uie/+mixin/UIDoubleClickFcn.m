classdef UIDoubleClickFcn < handle
    % UIDOUBLECLICKFCN A mixin class for naming the callback that responds to a double-click action.

    properties
        % DoubleClickFcn - The name of the function to execute on a double-click.
        %
        % This should be a character vector with the name of a public method
        % in the corresponding TabController class.
        DoubleClickFcn (1,:) char = ''
    end

end