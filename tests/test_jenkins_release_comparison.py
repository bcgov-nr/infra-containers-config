import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest


WORKFLOW = Path(__file__).resolve().parents[1] / ".github/workflows/build-bitnami-jenkins-image.yml"
STEP = WORKFLOW.read_text().split(
    "      - name: Compare upstream release with GHCR latest\n", 1
)[1].split("\n  build-only:", 1)[0]
SCRIPT = textwrap.dedent(STEP.split("        run: |\n", 1)[1])

MOCK_CURL = r"""
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
url = next(arg for arg in args if arg.startswith("https://"))
fixture = json.loads(os.environ["REGISTRY_FIXTURE"])
status = 200
digest = "sha256:" + "a" * 64
if url.endswith("/token"):
    status = fixture.get("token_status", 200)
    body = {"token": "test-registry-token"}
elif url.endswith("/manifests/latest"):
    status = fixture.get("status", 200)
    if fixture.get("index"):
        body = {"manifests": [{
            "platform": {"os": "linux", "architecture": fixture.get("arch", "amd64")},
            "digest": fixture.get("manifest_digest", digest),
        }]}
    else:
        body = {"config": {"digest": fixture.get("config_digest", digest)}}
elif "/manifests/" in url:
    status = fixture.get("child_status", 200)
    body = {"config": {"digest": fixture.get("config_digest", digest)}}
else:
    status = fixture.get("config_status", 200)
    body = {"config": {"Labels": {}}}
    if "current" in fixture:
        body["config"]["Labels"]["org.opencontainers.image.version"] = fixture["current"]
if status >= 400 and "-fsSL" in args:
    print(f"curl: HTTP {status}", file=sys.stderr)
    sys.exit(22)
if "--output" in args:
    Path(args[args.index("--output") + 1]).write_text(json.dumps(body))
else:
    print(json.dumps(body))
if "--write-out" in args:
    print(status, end="")
"""


class ReleaseComparisonTests(unittest.TestCase):
    def run_comparison(self, fixture, latest="2.580.2-debian-12-r0"):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            curl = root / "curl"
            curl.write_text(f"#!{sys.executable}\n" + textwrap.dedent(MOCK_CURL))
            curl.chmod(0o755)
            summary = root / "summary"
            env = {
                **os.environ,
                "PATH": f"{root}{os.pathsep}{os.environ['PATH']}",
                "GHCR_TOKEN": "test-github-token",
                "GITHUB_ACTOR": "test-actor",
                "IMAGE_PATH": "Example/Repository/jenkins",
                "LATEST_TAG": latest,
                "GITHUB_STEP_SUMMARY": str(summary),
                "REGISTRY_FIXTURE": json.dumps(fixture),
            }
            result = subprocess.run(
                ["bash", "-c", SCRIPT], env=env, capture_output=True, text=True
            )
            return result, summary.read_text() if summary.exists() else ""

    def test_comparison_outcomes(self):
        cases = [
            ("2.580.1-debian-12-r2", "2.580.2-debian-12-r0", "Update available"),
            ("2.580.2-debian-12-r0", "2.580.2-debian-12-r0", "Already current"),
            ("2.580.3-debian-12-r0", "2.580.2-debian-12-r0", "GHCR is newer"),
            ("2.580.2-debian-12-r2", "2.580.2-debian-12-r10", "Update available"),
            ("2.580.2-debian-12-r10", "2.580.2-debian-12-r2", "GHCR is newer"),
            ("2.99.9-debian-12-r99", "2.100.0-debian-12-r0", "Update available"),
            ("2.580.9-debian-12-r0", "2.580.10-debian-12-r0", "Update available"),
        ]
        for current, latest, expected in cases:
            for index in (False, True):
                with self.subTest(current=current, latest=latest, index=index):
                    result, summary = self.run_comparison(
                        {"current": current, "index": index}, latest
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn(expected, summary)
                    self.assertIn(current, summary)
                    self.assertIn(latest, summary)

    def test_missing_latest(self):
        result, summary = self.run_comparison({"status": 404})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("No latest image exists", summary)

    def test_errors_are_not_reported_as_updates(self):
        cases = [
            {"status": 401},
            {"status": 403},
            {"status": 500},
            {"token_status": 403},
            {"index": True, "child_status": 404},
            {"config_status": 500},
            {"index": True, "arch": "arm64"},
            {"index": True, "manifest_digest": "invalid"},
            {"config_digest": "invalid"},
            {},
            {"current": ""},
            {"current": "latest"},
            {"current": "2.580.2-debian-11-r0"},
        ]
        for fixture in cases:
            with self.subTest(fixture=fixture):
                result, summary = self.run_comparison(fixture)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("Update available", summary)
                self.assertNotIn("Already current", summary)
                self.assertNotIn("No latest image exists", summary)


if __name__ == "__main__":
    unittest.main()
