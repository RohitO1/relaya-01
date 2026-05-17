import re, sys

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix Border.all(color: X.withOpacity(0.3),  ->  Border.all(color: X.withOpacity(0.3)),
    # Pattern: Border.all( ... .withOpacity(0.3), followed by newline (missing closing paren)
    content = re.sub(
        r'Border\.all\(color: ([^)]+)\.withOpacity\(0\.3\),\s*\n',
        lambda m: f'Border.all(color: {m.group(1)}.withOpacity(0.3)),\n',
        content
    )
    
    # Fix BoxShadow(color: X.withOpacity(0.3), ... ]) without closing the BoxDecoration
    # Pattern: boxShadow: [BoxShadow(color: X.withOpacity(0.3), blurRadius: N)],  -> missing ) for BoxDecoration
    # These are cases where BoxDecoration is missing its closing )
    # Fix: border: Border.all(color: X.withOpacity(0.3), width: N)  - these are fine
    
    # Fix BoxShadow lines that lost a paren: 
    # boxShadow: [BoxShadow(color: X.withOpacity(0.3), blurRadius: 10)]),
    # This pattern is actually fine - the ]) closes the list and BoxDecoration
    
    # The real issue: lines like:
    # border: Border.all(color: X.withOpacity(0.3),
    # boxShadow: ...
    # Where Border.all is not closed before boxShadow starts
    # Already fixed above.
    
    # Also fix: BorderSide(color: X.withOpacity(0.3), -> BorderSide(color: X.withOpacity(0.3)),
    content = re.sub(
        r'BorderSide\(color: ([^)]+)\.withOpacity\(0\.3\),\s*\n',
        lambda m: f'BorderSide(color: {m.group(1)}.withOpacity(0.3)),\n',
        content
    )
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Fixed {filepath}")

for f in sys.argv[1:]:
    fix_file(f)
