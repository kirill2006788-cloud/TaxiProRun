"""Check the Git file list without ever printing matched credential values."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
names = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0")
patterns = [
    ("private key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("GitHub token", re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b")),
    ("Firebase API key", re.compile(r"\bAIza[A-Za-z0-9_-]{35}\b")),
    ("AWS access key", re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b")),
    ("embedded credential", re.compile(r"(?i)(?:password|passwd|api[_-]?key|access[_-]?token|jwt[_-]?secret)\s*[:=]\s*['\"]([^'\"\n]{10,})['\"]")),
]
failures = []
for name in filter(None, names):
    path = root / name
    lower = name.lower()
    if (path.name == '.env' or lower.endswith(('.jks', '.keystore', '.p12', '.apk', '.aab'))
            or path.name in ('google-services.json', 'GoogleService-Info.plist', 'key.properties', 'keys.local.env')):
        failures.append((name, 0, 'private or generated file'))
    if not path.is_file() or path.stat().st_size > 5_000_000:
        continue
    try:
        text = path.read_text(encoding='utf-8')
    except (UnicodeError, OSError):
        continue
    for label, pattern in patterns:
        for match in pattern.finditer(text):
            if label == 'embedded credential':
                value = match.group(1).lower()
                if (any(word in value for word in ('your_', 'your-', 'example', 'test-', 'test_', 'synthetic', 'placeholder', 'process.env', '${', 'local-test'))
                        or lower.startswith(('test/', 'admin/tests/', 'backend/api/tests/'))
                        or lower.endswith('.spec.ts') or ' ' in value or '<' in value):
                    continue
            failures.append((name, text.count('\n', 0, match.start()) + 1, label))
for name, line, label in failures:
    print(f'{name}:{line}: {label} [value hidden]')
print(f'Public source scan: {len(list(filter(None, names)))} files, {len(failures)} finding(s).')
sys.exit(bool(failures))
