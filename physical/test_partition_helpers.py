import unittest

from partition_helpers import validate_partition_areas


class PartitionAreaTests(unittest.TestCase):
    def test_standard_cell_only_balance(self):
        self.assertEqual(validate_partition_areas([25]*4, [25]*4), 0.25)

    def test_rf_failed_ci_checkpoint(self):
        # GDS 37568117521: RF is fixed in group 3. The movable-only group 1
        # share is 32.03%, but the actual partition weight share is 29.32%.
        partition = [38561.984, 55489.4688, 48396.416, 46811.664]
        movable = [38043.9872, 54997.7472, 47829.6224, 30849.5872]
        self.assertGreater(max(movable)/sum(movable), 0.30)
        self.assertLess(validate_partition_areas(partition, movable), 0.30)

    def test_real_imbalance_still_fails_with_macro(self):
        with self.assertRaisesRegex(ValueError, 'Unbalanced partitions'):
            validate_partition_areas([20, 40, 20, 20], [20, 25, 20, 20])

    def test_original_bound_remains_strict(self):
        with self.assertRaisesRegex(ValueError, 'Unbalanced partitions'):
            validate_partition_areas([30, 25, 25, 20], [30, 25, 25, 20])

    def test_empty_movable_partition_cannot_form_seed_window(self):
        with self.assertRaisesRegex(ValueError, 'positive movable areas'):
            validate_partition_areas([25]*4, [25, 25, 25, 0])

    def test_inconsistent_population_rejected(self):
        with self.assertRaisesRegex(ValueError, 'exceeds'):
            validate_partition_areas([25]*4, [26, 25, 25, 25])

    def test_invalid_area_rejected(self):
        for bad in [float('nan'), float('inf'), -1, 0]:
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                validate_partition_areas([25, 25, 25, bad], [25]*4)
