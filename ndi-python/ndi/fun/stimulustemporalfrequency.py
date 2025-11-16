"""
Extract temporal frequency from stimulus parameters.

MATLAB source: ndi/+ndi/+fun/stimulustemporalfrequency.m

Determines temporal frequency of stimuli based on predefined rules
loaded from a JSON configuration file.
"""

from typing import Tuple, Optional, Dict, Any
import warnings


def stimulustemporalfrequency(
    stimulus_parameters: Dict[str, Any]
) -> Tuple[Optional[float], Optional[str]]:
    """
    Extract temporal frequency from stimulus parameters using predefined rules.

    MATLAB equivalent: ndi.fun.stimulustemporalfrequency()

    Determines the temporal frequency (TF) of a stimulus based on its
    parameters. Uses rules from a configuration file to interpret various
    parameter encodings:
    - Direct value: Parameter directly represents TF in Hz
    - Scaled/Offset value: Parameter needs multiplication/addition
    - Period value: Parameter is temporal period, needs inversion (1/value)
    - Multi-parameter: Calculation involves multiple parameters

    Args:
        stimulus_parameters: Dictionary of stimulus parameter names and values

    Returns:
        Tuple of (tf_value, tf_name) where:
            tf_value: Calculated temporal frequency in Hz (or None if not found)
            tf_name: Name of parameter used for calculation (or None)

    Example:
        >>> params = {'temporalFrequency': 5.0}
        >>> tf_value, tf_name = stimulustemporalfrequency(params)
        >>> print(f'TF = {tf_value} Hz from {tf_name}')

    Note:
        This function requires a JSON configuration file:
        ndi/common/stimulus/ndi_stimulusparameters2temporalfrequency.json

        The configuration defines rules for known temporal frequency parameter
        names and how to calculate TF from them.

        Current Status: PLACEHOLDER - Returns (None, None)
        Full implementation deferred until configuration infrastructure is available.
    """
    warnings.warn(
        "stimulustemporalfrequency is not fully implemented. "
        "Requires JSON configuration file and stimulus parameter parsing rules. "
        "Returns (None, None) as placeholder.",
        UserWarning,
        stacklevel=2
    )

    # Would implement:
    # 1. Load configuration from JSON file
    # 2. Check stimulus_parameters keys against known TF parameter names
    # 3. Apply calculation rules based on configuration
    # 4. Return calculated TF and parameter name

    # Check for common parameter names as fallback
    common_tf_names = ['temporalFrequency', 'temporal_frequency', 'tf', 'freq']
    for name in common_tf_names:
        if name in stimulus_parameters:
            value = stimulus_parameters[name]
            if isinstance(value, (int, float)):
                # Direct value - return as-is
                return (float(value), name)

    # No recognized parameter found
    return (None, None)
