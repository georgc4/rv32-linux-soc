import unittest
from eco_helpers import failing_pins,def_routes,neighborhood


class ReportTests(unittest.TestCase):
    def test_both_electrical_sections_not_fanout(self):
        text='max slew\n\nPin Limit Slew Slack\na/A 1.5 1.6 -0.1 (VIOLATED)\n\nmax fanout\n\nb/X 5 6 -1 (VIOLATED)\n\nmax capacitance\n\nPin Limit Cap Slack\na/A 0.2 0.3 -0.1 (VIOLATED)\nc/X 0.2 0.4 -0.2 (VIOLATED)\n\n'
        self.assertEqual(failing_pins(text),{'a/A','c/X'})
    def test_zero_count_summary_without_sections(self):
        self.assertEqual(failing_pins("max slew violation count 0\nmax cap violation count 0\n"),set())
    def test_nonzero_count_without_section_fails(self):
        with self.assertRaises(ValueError):failing_pins("max slew violation count 3\nmax cap violation count 0\n")
    def test_missing_section_fails(self):
        with self.assertRaises(ValueError):failing_pins('max slew\n\nNo violations\n\n')
    def test_clean_report(self):
        self.assertEqual(failing_pins('max slew\n\nPin Limit Slew Slack\n\nmax capacitance\n\nPin Limit Cap Slack\n\n'),set())


class GeometryTests(unittest.TestCase):
    def routes(self):
        return def_routes('''VERSION 5.8 ;
NETS 4 ;
    - target ( a X ) + ROUTED met1 ( 0 0 ) ( 100 * )
      NEW met2 ( 100 0 ) ( * 100 ) ;
    - nearby ( b A ) + ROUTED met1 ( 45 4 ) ( 55 * ) ;
    - inside_bbox_but_far ( c A ) + ROUTED met1 ( 30 70 ) ( 40 * ) ;
    - footprint ( d A ) + FIXED met1 ( 200 195 ) ( 220 * ) ;
END NETS
''')
    def test_relative_coordinates_and_path_reset(self):
        boxes=self.routes()['target'][1]
        self.assertIn((0,0,100,0),boxes);self.assertIn((100,0,100,100),boxes)
        self.assertNotIn((0,0,100,100),boxes)
    def test_unlock_corridor_and_cell_neighborhood(self):
        editable=neighborhood(self.routes(),{'target'},[(205,205,215,215)],20,5)
        self.assertEqual(editable,{'target','nearby','footprint'})
    def test_empty_eco_preserves_all(self):
        self.assertEqual(neighborhood(self.routes(),set(),[],20,5),set())
    def test_unknown_geometry_fails(self):
        with self.assertRaises(ValueError):def_routes('\nNETS 1 ;\n- bad + ROUTED met1 nonsense ;\nEND NETS')

if __name__=='__main__':unittest.main()
