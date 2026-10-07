"""Area checks for TritonPart's four-way placement seeds (no OpenDB dependency)."""
import math


def validate_partition_areas(partition_areas, movable_areas):
    """Check the partitioner's population, while requiring usable seed windows.

    TritonPart weights every instance in its solution by physical bounding-box
    area, including fixed macros and physical cells with Liberty views. Ports
    have zero weight. Movable-only area instead sizes our seed windows; applying
    the partition balance bound to that subset incorrectly rejects macro designs.
    """
    for label, areas in [('partition', partition_areas), ('movable', movable_areas)]:
        if len(areas) != 4 or any(not math.isfinite(a) or a <= 0 for a in areas):
            raise ValueError(f'Expected four positive {label} areas: {areas}')
    if any(m > p for p, m in zip(partition_areas, movable_areas)):
        raise ValueError('Movable area exceeds partition area')
    largest_share = max(partition_areas) / sum(partition_areas)
    if largest_share >= 0.30:
        raise ValueError(f'Unbalanced partitions: areas={partition_areas}, '
                         f'largest share={largest_share:.6f}, limit=0.30')
    return largest_share
