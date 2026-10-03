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

class RouteContactTests(unittest.TestCase):
    def contacts(self,first,second):
        from eco_helpers import route_crossings
        return route_crossings(def_routes('\nNETS 2 ;\n- a + FIXED '+first+' ;\n- b + ROUTED '+second+' ;\nEND NETS'))

    def test_failed_ci_crossing(self):
        result=self.contacts('met2 ( 490590 72930 ) ( * 74630 )',
                             'met2 ( 490130 74290 ) ( 491050 * )')
        self.assertEqual(result,[dict(nets=['a','b'],layer='met2',box_dbu=[490590,74290,490590,74290])])

    def test_different_layers_allowed(self):
        self.assertEqual(self.contacts('met1 ( 0 50 ) ( 100 * )','met2 ( 50 0 ) ( * 100 )'),[])

    def test_endpoint_touch_is_short(self):
        self.assertEqual(len(self.contacts('met1 ( 0 0 ) ( 100 * )','met1 ( 100 0 ) ( * 100 )')),1)

    def test_collinear_overlap(self):
        self.assertTrue(self.contacts('met1 ( 0 0 ) ( 100 * )','met1 ( 50 0 ) ( 150 * )'))

    def test_separate_wires_allowed(self):
        self.assertEqual(self.contacts('met1 ( 0 0 ) ( 100 * )','met1 ( 0 10 ) ( 100 * )'),[])

    def test_same_net_branches_allowed(self):
        from eco_helpers import route_crossings
        routes=def_routes('\nNETS 1 ;\n- a + ROUTED met2 ( 0 50 ) ( 100 * ) NEW met2 ( 50 0 ) ( * 100 ) ;\nEND NETS')
        self.assertEqual(route_crossings(routes),[])

class ContactRepairTests(unittest.TestCase):
    def select(self, pairs, editable=('a','b'), protected=('c',)):
        from eco_helpers import contact_repair_nets
        return contact_repair_nets([dict(nets=p) for p in pairs],editable,protected)

    def test_already_editable_contacts_still_need_ripup(self):
        self.assertEqual(self.select([['a','b']]),({'a','b'},set()))

    def test_mixed_contacts_promote_only_protected_members(self):
        self.assertEqual(self.select([['a','b'],['b','c']]),({'a','b','c'},{'c'}))

    def test_empty_unknown_and_self_contacts_fail(self):
        for pairs in [[],[['a','missing']],[['a','a']]]:
            with self.subTest(pairs=pairs),self.assertRaises(ValueError):self.select(pairs)

if __name__ == '__main__':
    unittest.main()
