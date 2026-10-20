function t = haleyTerm(name)
%HALEYTERM The decided ontology term for a name the Haley import writes.
%
%   T = haleyTerm(NAME) returns did2.build.term(NODE, NAME), NODE the CURIE
%   decided for NAME in the import's term pass (Jess Haley, 2026-10-19). A
%   name with no decided node is an error, so a misspelled or undecided term
%   is found when the import is built, not when the dataset is read. A
%   lab-specific label with no ontology term is written with
%   did2.build.term('', NAME) at its call site instead.
%
%   NAME may be a cellstr or string array, giving a 1xN term array (a key's
%   positions).

arguments
    name {mustBeText}
end
persistent nodes
if isempty(nodes)
    nodes = termTable();
end
name = cellstr(name);
node = cell(size(name));
for k = 1:numel(name)
    if ~isKey(nodes, name{k})
        error('ndi:setup:conv:haley:undecidedTerm', ...
            'No decided term for "%s": add it to haleyTerm''s table or write it as a label.', name{k});
    end
    node{k} = nodes(name{k});
end
t = did2.build.term(node, name);
end

function m = termTable()
%TERMTABLE name -> CURIE, grouped as the term pass decided them.
pairs = {
    % study, dataset, subjects, assertions
    'OD600',                                  'MCO:0000059'
    'bacteria growth duration after seeding', 'EMPTY:0000119'
    'food availability',                      'ZECO:0000113'
    'fasting',                                'ZECO:0000114'
    'organism strain',                        'NCIT:C14419'
    'species',                                'NCIT:C45293'
    'accessibility',                          'NCIT:C175887'
    'unrestricted access',                    'NCIT:C183346'
    'wild type',                              'NCIT:C62195'
    'mutant',                                 'NCIT:C25360'
    'transgenic organism',                    'OBI:1000048'
    'video recording',                        'NCIT:C91063'
    'inclusion in analysis',                  'EMPTY:0000314'
    'diameter',                               'PATO:0001334'
    'spacing',                                'NCIT:C45786'
    'value basis',                            'EMPTY:0000298'
    'target',                                 'EMPTY:0000299'
    'intervalDuring',                         'time:intervalDuring'
    % manipulations, observations
    'ambient temperature',                    'NCIT:C90380'
    'relative humidity',                      'om:RelativeHumidity'
    'location',                               'NCIT:C25341'
    'image intensity',                        'NCIT:C221750'
    'culture medium',                         'OBI:0000079'
    'bacterial patch volume',                 'EMPTY:0000120'
    'bacterial OD600 (target) at seeding',    'EMPTY:0000105'
    % formulation types
    'LB medium, Lennox',                      'MCO:0000030'
    'LB with carbenicillin',                  'EMPTY:0000264'
    'nematode growth medium',                 'EMPTY:0000262'
    'nematode growth medium without peptone', 'EMPTY:0000263'
    'S basal',                                'EMPTY:0000265'
    'S medium',                               'EMPTY:0000266'
    'trace metals solution',                  'MICRO:0000455'
    'potassium phosphate buffer',             'NCIT:C29321'
    'potassium citrate solution',             'NCIT:C70815'
    'magnesium sulfate solution',             'EMPTY:0000267'
    'calcium chloride solution',              'EMPTY:0000268'
    'potassium phosphate monobasic solution', 'EMPTY:0000269'
    'potassium phosphate dibasic solution',   'EMPTY:0000270'
    'cholesterol solution',                   'EMPTY:0000271'
    % chemicals
    'water',                                  'CHEBI:15377'
    'agar',                                   'CHEBI:2509'
    'sodium chloride',                        'CHEBI:26710'
    'peptone',                                'MICRO:0000178'
    'tryptone',                               'MICRO:0000182'
    'yeast extract',                          'MICRO:0000201'
    'potassium dihydrogen phosphate',         'CHEBI:63036'
    'dipotassium hydrogen phosphate',         'CHEBI:131527'
    'dipotassium hydrogen phosphate trihydrate', 'EMPTY:0000313'
    'magnesium sulfate',                      'CHEBI:32599'
    'calcium chloride dihydrate',             'CHEBI:86158'
    'cholesterol',                            'CHEBI:16113'
    'ethanol',                                'CHEBI:16236'
    'citric acid monohydrate',                'CHEBI:31404'
    'tripotassium citrate monohydrate',       'CHEBI:64746'
    'disodium EDTA dihydrate',                'CHEBI:64758'
    'iron(II) sulfate heptahydrate',          'CHEBI:75836'
    'manganese(II) chloride tetrahydrate',    'CHEBI:86368'
    'zinc sulfate heptahydrate',              'CHEBI:32312'
    'copper(II) sulfate pentahydrate',        'CHEBI:31440'
    'carbenicillin',                          'CHEBI:3393'
    % geometry, masks, tracks
    'brightfield imaging',                    'EMPTY:0000300'
    'fluorescence microscopy',                'NCIT:C16856'
    'video tracking',                         'EMPTY:0000301'
    'moving average',                         'OBI:0200056'
    'distance transform',                     'EMPTY:0000302'
    'image segmentation',                     'OBI:0003918'
    'image registration',                     'NCIT:C80145'
    'window',                                 'NCIT:C48921'
    'interpolation method',                   'EMPTY:0000305'
    'linear interpolation',                   'EMPTY:0000306'
    'maximum gap filled',                     'EMPTY:0000307'
    'plate or arena diameter',                'EMPTY:0000122'
    'position',                               'PATO:0000140'
    'speed',                                  'PATO:0000008'
    'distance',                               'PATO:0000040'
    'acceleration',                           'PATO:0001028'
    'radius',                                 'PATO:0002390'
    'circularity',                            'EMPTY:0000288'
    'overlap',                                'NCIT:C54669'
    'fraction',                               'NCIT:C25514'
    'reference point',                        'NCIT:C45793'
    'nearest bacterial patch edge',           'EMPTY:0000276'
    'nearest bacterial patch',                'EMPTY:0000297'
    'bacterial patch mask',                   'EMPTY:0000131'
    'body part',                              'EMPTY:0000135'
    'head',                                   'EMPTY:0000136'
    'midpoint',                               'EMPTY:0000137'
    'tail',                                   'EMPTY:0000138'
    % E. coli
    'fluorescence intensity',                 'NCIT:C184706'
    'normalization to background illumination', 'EMPTY:0000287'
    'maximum',                                'STATO:0000151'
    'minimum',                                'STATO:0000150'
    'mean',                                   'STATO:0000573'
    'median',                                 'STATO:0000574'
    'baseline',                               'NCIT:C25213'
    'bacterial patch edge',                   'EMPTY:0000283'
    'bacterial patch center',                 'EMPTY:0000284'
    'bacterial patch fluorescence peak',      'EMPTY:0000285'
    'distance end point',                     'EMPTY:0000286'
    'bin width',                              'EMPTY:0000308'
    % encounters
    'encounter onset time',                   'EMPTY:0000140'
    'encounter',                              'NCIT:C62143'
    'patch encounter detection',              'EMPTY:0000303'
    'bacterial patch in contact',             'EMPTY:0000275'
    'patch encounter period',                 'EMPTY:0000277'
    'before the first patch encounter',       'EMPTY:0000278'
    'during the patch encounter',             'EMPTY:0000279'
    'after the patch encounter',              'EMPTY:0000280'
    'peak speed before an event',             'EMPTY:0000272'
    'minimum speed after an event',           'EMPTY:0000273'
    'time to slow down',                      'EMPTY:0000274'
    'reference time point',                   'NCIT:C82576'
    'analysis window start',                  'EMPTY:0000281'
    'analysis window end',                    'EMPTY:0000282'
    'ordinary least squares estimation',      'STATO:0000370'
    'posterior probability',                  'STATO:0000703'
    'probability',                            'NCIT:C54154'
    'behavioral state',                       'EMPTY:0000289'
    'exploitation',                           'EMPTY:0000290'
    'sensing',                                'EMPTY:0000291'
    'encounter type',                         'EMPTY:0000292'
    'exploit',                                'EMPTY:0000293'
    'sample',                                 'EMPTY:0000294'
    'search on patch',                        'EMPTY:0000295'
    'search off patch',                       'EMPTY:0000296'
    'classification',                         'NCIT:C25161'
    'cannot be determined',                   'NCIT:C179711'
    'Gaussian mixture model clustering',      'EMPTY:0000316'
    'quadratic discriminant analysis',        'EMPTY:0000317'
    % fits and estimates
    'slope',                                  'STATO:0000656'
    'intercept',                              'STATO:0000657'
    'coefficient of determination',           'STATO:0000564'
    'prediction from a fitted model',         'EMPTY:0000304'
    'linear regression',                      'STATO:0000108'
    'regression coefficient',                 'STATO:0000565'
    % masks, plates, development (decided with Jess 2026-10-20)
    'arena mask',                             'EMPTY:0000130'
    'reference mark mask',                    'EMPTY:0000318'
    'acclimation plate',                      'EMPTY:0000319'
    'food deprivation plate',                 'EMPTY:0000320'
    'assay plate',                            'EMPTY:0000321'
    'developmental stage',                    'NCIT:C43531'
    'L4 larva',                               'WBls:0000038'
    'visual inspection',                      'NCIT:C214703'
    % keys, coordinates, units
    'video frame',                            'EMPTY:0000309'
    'coordinate',                             'NCIT:C44465'
    'X-coordinate',                           'NCIT:C44477'
    'Y-coordinate',                           'NCIT:C44478'
    'x-axis',                                 'STATO:0000006'
    'y-axis',                                 'STATO:0000008'
    'image upper-left corner',                'EMPTY:0000310'
    'image right',                            'EMPTY:0000311'
    'image down',                             'EMPTY:0000312'
    'meter',                                  'om:metre'
    'liter',                                  'om:litre'
    'second',                                 'om:second-Time'
    'minute',                                 'om:minute-Time'
    'hour',                                   'om:hour'
    'meter per second',                       'om:metrePerSecond-Time'
    'meter per second squared',               'om:metrePerSecond-TimeSquared'
    'pixel',                                  'NCIT:C48367'
    'frame',                                  'EMPTY:0000260'
    'arbitrary unit per millisecond',         'EMPTY:0000261'
    };
m = containers.Map(pairs(:, 1), pairs(:, 2));
end
