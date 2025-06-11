classdef UIWordWrap < handle
    % UIWORDWRAP A mixin class for the WordWrap property.

    properties
        % WordWrap - Specifies whether to wrap long text onto multiple lines.
        %
        % Must be either 'on' or 'off' (default).
        WordWrap (1,:) char {mustBeMember(WordWrap,{'on','off'})} = 'off'
    end
end