"""Mac-only archive-script regression checks using real Mach-O binaries."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name('generate_sentry_stub_dsym.sh')


class SentryStubSymbolsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='sentry symbols ')
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.app = root / 'Runner.app'
        self.binary = self.app / 'Frameworks/Sentry.framework/Sentry'
        self.binary.parent.mkdir(parents=True)
        self.symbols = root / 'dSYMs'
        self.env = dict(os.environ, ACTION='install',
                        TARGET_BUILD_DIR=str(self.app),
                        FRAMEWORKS_FOLDER_PATH='Frameworks',
                        DWARF_DSYM_FOLDER_PATH=str(self.symbols))

    def compile(self, code):
        subprocess.run(['xcrun', 'clang', '-dynamiclib', '-x', 'c', '-',
                        '-o', str(self.binary)], input=code, text=True, check=True)

    def run_script(self):
        return subprocess.run(['/bin/bash', str(SCRIPT)], env=self.env,
                              capture_output=True, text=True)

    def test_empty_stub_has_matching_valid_symbols_and_is_idempotent(self):
        self.compile('')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        dwarf = self.symbols / 'Sentry.framework.dSYM/Contents/Resources/DWARF/Sentry'
        uuid = lambda path: subprocess.check_output(
            ['xcrun', 'dwarfdump', '--uuid', str(path)], text=True).split()[1]
        self.assertEqual(uuid(self.binary), uuid(dwarf))
        subprocess.run(['xcrun', 'dwarfdump', '--verify', str(dwarf)],
                       check=True, capture_output=True)
        before = dwarf.stat().st_mtime_ns
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(dwarf.stat().st_mtime_ns, before)

    def test_real_sdk_code_requires_original_symbols(self):
        self.compile('int real_sdk_function(void) { return 42; }')
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('not an empty Xcode stub', result.stdout)
        self.assertFalse(self.symbols.exists())

    def test_non_archive_build_is_untouched(self):
        self.compile('')
        self.env['ACTION'] = 'build'
        self.assertEqual(self.run_script().returncode, 0)
        self.assertFalse(self.symbols.exists())

    def test_absent_resource_framework_is_untouched(self):
        self.assertEqual(self.run_script().returncode, 0)
        self.assertFalse(self.symbols.exists())


if __name__ == '__main__':
    unittest.main()
