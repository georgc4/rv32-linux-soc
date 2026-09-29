"""Versioned, explicit physical options for the locality campaign."""

CLUSTER_PROFILES = ("none", "timer_csr", "operands", "cache", "combined")
CORNER_PROFILES = ("default", "multicorner")
OPTIONS = {
    "timing_driven": False,
    "corner_profile": "default",
    "cluster_profile": "none",
    "post_grt_timing": False,
    "max_cores": 4,
}


def validate(options):
    if set(options) - set(OPTIONS):
        raise ValueError("unsupported physical options")
    values = {**OPTIONS, **options}
    if any(type(values[k]) is not bool for k in ("timing_driven", "post_grt_timing")):
        raise ValueError("timing options must be booleans")
    if values["corner_profile"] not in CORNER_PROFILES:
        raise ValueError("unknown corner profile")
    if values["cluster_profile"] not in CLUSTER_PROFILES:
        raise ValueError("unknown placement cluster profile")
    if type(values["max_cores"]) is not int or not 1 <= values["max_cores"] <= 12:
        raise ValueError("max_cores must be between 1 and 12")
    return values


def flow_overrides(options):
    o = validate(options)
    result = {
        "PL_TIMING_DRIVEN": o["timing_driven"],
        "RUN_POST_GRT_RESIZER_TIMING": o["post_grt_timing"],
        "DRT_THREADS": o["max_cores"],
        "STA_THREADS": min(2, o["max_cores"]),
    }
    if o["corner_profile"] == "multicorner":
        result.update({
            "PNR_CORNERS": ["nom_tt_025C_1v80", "max_ss_100C_1v60", "min_ff_n40C_1v95"],
            "RSZ_CORNERS": ["nom_tt_025C_1v80", "max_ss_100C_1v60", "min_ff_n40C_1v95"],
            "SETUP_VIOLATION_CORNERS": ["*"],
            "HOLD_VIOLATION_CORNERS": ["*"],
        })
    if o["cluster_profile"] != "none":
        result.update({
            "LOCALITY_PROFILE": o["cluster_profile"],
            "meta": {"version": 1, "flow": "Classic", "substituting_steps": {
                "OpenROAD.GlobalPlacement": "Locality.GlobalPlacement",
            }},
        })
    return result
