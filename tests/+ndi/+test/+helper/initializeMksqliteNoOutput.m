function initializeMksqliteNoOutput()
% initializeMksqliteNoOutput - Capure mksqlite initialization message. 

    % Small helper function to ensure the mksqlite initialization message
    % does not spam the test log
    C = evalc( "mksqlite('version sql')" ); %#ok<NASGU>
end
