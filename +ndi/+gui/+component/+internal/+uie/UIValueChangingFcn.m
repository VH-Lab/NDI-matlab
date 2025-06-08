classdef UIValueChangingFcn < ndi.util.StructSerializable
    % UIVALUECHANGINGFCN A mixin class for naming the ValueChangingFcn callback.
    %
    % This is for components where an action should be taken in real-time as
    % the user interacts, such as typing in an edit field or dragging a slider.

    properties
        % ValueChangingFcn - The name of the function to execute as the value is changing.
        %
        % This should be a character vector with the name of a public method
        % in the corresponding TabController class.
        ValueChangingFcn (1,:) char = ''
    end

end