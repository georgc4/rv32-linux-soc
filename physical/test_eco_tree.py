import json
import math
from pathlib import Path
import random
import unittest

from eco_tree import shared_buffer_tree


class TreeTests(unittest.TestCase):
    def verify_tree(self, driver, sinks, plan):
        nodes = plan['buffers']
        sink_xy = {p[0]: p[1:] for p in sinks}
        seen_pins, seen_buffers = [], []
        bounds = plan['bounds']

        def visit(origin, refs, parent_id):
            self.assertLessEqual(len(refs), bounds['max_sinks'])
            for ref in refs:
                self.assertIn(set(ref), ({'pin'}, {'buffer'}))
                if 'pin' in ref:
                    seen_pins.append(ref['pin'])
                    xy = sink_xy[ref['pin']]
                else:
                    child_id = ref['buffer']
                    self.assertLess(child_id, parent_id, 'must reference an earlier insertion')
                    seen_buffers.append(child_id)
                    child = nodes[child_id]
                    self.assertEqual(child['id'], child_id)
                    self.assertIn(child['cell'], ('sky130_fd_sc_hd__buf_4', 'sky130_fd_sc_hd__buf_8'))
                    xy = child['point_um']
                self.assertLessEqual(sum(abs(a-b) for a,b in zip(origin,xy)),
                                     bounds['max_segment_um']+1e-8)
        visit(driver, plan['root_loads'], len(nodes))
        for node in nodes:
            visit(node['point_um'], node['loads'], node['id'])
        self.assertEqual(sorted(seen_pins), sorted(sink_xy), 'lost or duplicated sink')
        self.assertEqual(sorted(seen_buffers), list(range(len(nodes))), 'orphan/shared/cyclic buffer')

    def test_remote_cluster_shares_trunk(self):
        sinks = [(f'p{i}', 600+i%8, i//8) for i in range(64)]
        plan = shared_buffer_tree((0,0), sinks)
        self.verify_tree((0,0), sinks, plan)
        independent = sum(max(0,math.ceil((abs(x)+abs(y))/80)-1) for _,x,y in sinks)
        self.assertLess(len(plan['buffers']), independent//4)

    def test_close_sinks_keep_resized_driver_only(self):
        sinks = [('a',1,2),('b',3,4)]
        plan = shared_buffer_tree((0,0), sinks)
        self.assertEqual(plan['buffers'], [])
        self.verify_tree((0,0), sinks, plan)

    def test_force_repair_and_empty(self):
        sinks = [('a',2,4)]
        plan = shared_buffer_tree((0,0), sinks, force=True)
        self.assertEqual(len(plan['buffers']), 1)
        self.verify_tree((0,0), sinks, plan)
        self.assertEqual(shared_buffer_tree((0,0), [])['buffers'], [])

    def test_random_geometry_preserves_connectivity_and_bounds(self):
        rng = random.Random(310)
        for count in (1,2,8,9,30,100):
            sinks = [(f'p{i}', rng.uniform(-500,500), rng.uniform(-500,500)) for i in range(count)]
            plan = shared_buffer_tree((10,20), sinks)
            self.verify_tree((10,20), sinks, plan)
            self.assertEqual(plan, shared_buffer_tree((10,20), list(reversed(sinks))))

    def test_reject_invalid_inputs(self):
        for sinks in ([('p',0,0),('p',1,1)], [('p',float('nan'),0)]):
            with self.assertRaises(ValueError):
                shared_buffer_tree((0,0), sinks)
        with self.assertRaises(ValueError):
            shared_buffer_tree((0,0), [], spacing=0)

    def test_failed_ci_design_now_fits_buffer_budget(self):
        fixture = json.loads((Path(__file__).parent/'fixtures/ci-36811470893-eco-geometry.json').read_text())
        shared, old = 0, 0
        for net in fixture['nets']:
            if net['kind'] == 'clock_split':
                shared += net['buffers']; old += net['buffers']
                continue
            plan = shared_buffer_tree(net['driver_um'], net['sinks_um'])
            self.verify_tree(net['driver_um'], net['sinks_um'], plan)
            shared += len(plan['buffers'])
            old += net['independent_chain_buffers']
        self.assertEqual(old, 874)
        self.assertLessEqual(shared, 250)
        self.assertLess(shared, old//2)


if __name__ == '__main__':
    unittest.main()
