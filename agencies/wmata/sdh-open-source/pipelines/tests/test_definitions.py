from dagster import Definitions
from ..definitions import defs


def test_definitions_loadable():
    # validate definitions are loadable using builtin - note this returns None on success and errors otherwise
    try:
        Definitions.validate_loadable(defs)
    except Exception as e:
        raise AssertionError(f"Definitions validation failed: {e}")

    # test resource initialization and that required fields are set
    try:
        _ = (
            defs.get_asset_value_loader()
        )  # we're just interested that this runs without error
    except Exception as e:
        raise AssertionError(f"Resource configuration failed: {e}")
