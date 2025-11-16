"""
NDI Probe - Measurement or stimulation instruments.
"""

from .element import Element


class Probe(Element):
    """
    NDI Probe - represents a measurement or stimulation probe.

    Probes are elements that directly interface with subjects through DAQ systems.
    Examples: electrodes, cameras, stimulus monitors, speakers, etc.
    """

    def __init__(
        self,
        session,
        name: str,
        reference: int,
        probe_type: str,
        subject_id: str
    ):
        """
        Create a probe.

        Args:
            session: Parent session
            name: Probe name
            reference: Reference number
            probe_type: Type of probe
            subject_id: Associated subject ID
        """
        super().__init__(
            session=session,
            name=name,
            reference=reference,
            element_type=probe_type,
            underlying_element=None,
            direct=True,
            subject_id=subject_id
        )

    def probestring(self) -> str:
        """
        Get a human-readable probe string.

        Returns:
            str: Probe string
        """
        return self.elementstring()

    def __repr__(self) -> str:
        """String representation."""
        return f"Probe(name='{self.name}', type='{self.type}', ref={self.reference})"
