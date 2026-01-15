#!/usr/bin/env python
"""Fix madmom compatibility with newer numpy versions."""
import os
import re

madmom_path = r'G:\git_repos\rhythm_coach\quick_start_experiment\venv\lib\site-packages\madmom'

# Files that need fixing based on grep results
files_to_fix = [
    'audio/filters.py',
    'audio/signal.py',
    'audio/stft.py',
    'evaluation/beats.py',
    'evaluation/chords.py',
    'evaluation/onsets.py',
    'evaluation/notes.py',
    'evaluation/tempo.py',
    'evaluation/__init__.py',
    'io/midi.py',
    'utils/__init__.py',
    'utils/midi.py',
    'features/notes.py',
    'features/beats_hmm.py',
    'features/downbeats.py',
    'features/beats.py',
    'features/tempo.py',
    'features/onsets.py',
]

def fix_file(filepath):
    """Replace deprecated numpy types in a file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    # Replace np.float with np.float64
    content = re.sub(r'\bnp\.float\b', 'np.float64', content)

    # Replace np.int with np.int64
    content = re.sub(r'\bnp\.int\b', 'np.int64', content)

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

# Fix all files
fixed_count = 0
for file in files_to_fix:
    filepath = os.path.join(madmom_path, file)
    if os.path.exists(filepath):
        if fix_file(filepath):
            print(f"Fixed: {file}")
            fixed_count += 1
    else:
        print(f"Not found: {file}")

print(f"\nTotal files fixed: {fixed_count}")
