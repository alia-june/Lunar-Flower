"""Exercise the duplicate paths observed in the supplied ReShade log."""

from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import shutil

from install_twin_lantern_alpha import ALPHA, OBSOLETE, SOURCE, repair


class RepairTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.game = Path(self.temp.name)
        self.shaders = self.game / "reshade-shaders/Shaders"
        self.canonical = self.shaders / "camera_obscura/effects" / ALPHA
        self.nested = self.shaders / "Twin-Lanterns/Full-Resolution-Dual-Ray-Alpha/reshade-shaders/Shaders/camera_obscura/effects" / ALPHA
        self.old = self.canonical.with_name(OBSOLETE)
        self.keep = self.shaders / "ReShade.fxh"
        for path, data in [(self.canonical, b"old alpha"), (self.nested, b"duplicate alpha"), (self.old, b"obsolete"), (self.keep, b"known-good include"), (self.game / "ReShade.ini", b"preset and search paths")]:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)

    def inventory(self):
        return {str(p.relative_to(self.game)): p.read_bytes() for p in self.game.rglob("*") if p.is_file()}

    def test_preview_does_not_write(self):
        before = self.inventory()
        self.assertTrue(repair(self.game))
        self.assertEqual(before, self.inventory())

    def test_repair_preserves_originals_and_closes_include_paths(self):
        originals = {self.canonical: b"old alpha", self.nested: b"duplicate alpha", self.old: b"obsolete"}
        repair(self.game, apply=True)
        self.assertFalse(self.nested.exists())
        self.assertFalse(self.old.exists())
        self.assertEqual([self.canonical], list(self.shaders.rglob(ALPHA)))
        for source in SOURCE.rglob("*"):
            if source.suffix in {".fx", ".fxh"}:
                installed = self.shaders / "camera_obscura" / source.relative_to(SOURCE)
                self.assertEqual(source.read_bytes(), installed.read_bytes())
        backups = list((self.game / "Lunar-Flower-backups").iterdir())
        self.assertEqual(1, len(backups))
        for path, data in originals.items():
            self.assertEqual(data, (backups[0] / path.relative_to(self.game)).read_bytes())
        self.assertEqual(b"known-good include", self.keep.read_bytes())
        self.assertEqual(b"preset and search paths", (self.game / "ReShade.ini").read_bytes())

    def test_repeat_is_noop(self):
        repair(self.game, apply=True)
        before = self.inventory()
        self.assertEqual([], repair(self.game, apply=True))
        self.assertEqual(before, self.inventory())

    def test_unrelated_effect_is_preserved(self):
        unrelated = self.shaders / "other/OtherAlpha.fx"
        unrelated.parent.mkdir()
        unrelated.write_bytes(b"unrelated shader")
        repair(self.game, apply=True)
        self.assertEqual(b"unrelated shader", unrelated.read_bytes())

    def test_failed_install_restores_original_shader_files(self):
        before = {p: p.read_bytes() for p in self.shaders.rglob("*") if p.is_file()}
        copy = shutil.copy2
        writes = 0

        def fail_second_payload(source, target):
            nonlocal writes
            if Path(source).is_relative_to(SOURCE):
                writes += 1
                if writes == 2:
                    raise OSError("simulated write failure")
            return copy(source, target)

        with patch("install_twin_lantern_alpha.shutil.copy2", side_effect=fail_second_payload):
            with self.assertRaises(OSError):
                repair(self.game, apply=True)
        self.assertEqual(before, {p: p.read_bytes() for p in self.shaders.rglob("*") if p.is_file()})

    def test_rejects_linked_shader_directory_before_writes(self):
        with tempfile.TemporaryDirectory() as external:
            external = Path(external)
            (external / ALPHA).write_bytes(b"external")
            (self.shaders / "linked").symlink_to(external, target_is_directory=True)
            # Source destination links must also be refused.
            self.canonical.unlink()
            self.canonical.symlink_to(external / ALPHA)
            with self.assertRaises(ValueError):
                repair(self.game, apply=True)
            self.assertEqual(b"external", (external / ALPHA).read_bytes())
            self.assertTrue(self.old.exists())


if __name__ == "__main__":
    unittest.main()
