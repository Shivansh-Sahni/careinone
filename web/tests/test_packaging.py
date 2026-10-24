import shlex
import unittest
from pathlib import Path
class WebPackagingTests(unittest.TestCase):
    def test_web_image_uses_only_explicit_runtime_files_and_dedicated_ignore(self):
        root=Path(__file__).resolve().parents[2];docker=(root/'web/Dockerfile').read_text();ignore=(root/'web/Dockerfile.dockerignore').read_text().splitlines();self.assertIn('**',ignore)
        copied=[]
        for line in docker.splitlines():
            words=shlex.split(line)
            if words and words[0]=='COPY' and not words[1].startswith('--from='):copied.extend(words[1:-1])
        for source in copied:
            self.assertTrue((root/source).is_file(),source);self.assertIn('!'+source,ignore);self.assertNotIn('.env',source);self.assertNotIn('test',source)
        self.assertIn('USER 10001',docker);self.assertIn('--no-access-log',docker);self.assertIn('${PORT:-10000}',docker)
    def test_original_native_backend_packaging_is_still_independent(self):
        root=Path(__file__).resolve().parents[2]
        self.assertNotIn('web/',(root/'backend/Dockerfile').read_text());self.assertNotIn('web/',(root/'.dockerignore').read_text())
