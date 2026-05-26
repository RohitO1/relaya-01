const fs = require('fs');
let c = fs.readFileSync('lib/onboarding_screen.dart', 'utf8');

// ── 1. Replace _s15Preferences using brace-depth approach ──
const marker = '  Widget _s15Preferences() {';
const start = c.indexOf(marker);
let depth = 0, inBody = false, end = -1;
for (let i = start; i < c.length; i++) {
  if (c[i] === '{') { depth++; inBody = true; }
  else if (c[i] === '}') { depth--; if (inBody && depth === 0) { end = i + 1; break; } }
}

const langs = ['Hindi', 'English', 'Bengali', 'Marathi', 'Telugu', 'Tamil', 'Gujarati', 'Kannada', 'Odia', 'Malayalam', 'Punjabi', 'Assamese', 'Maithili', 'Urdu', 'Sanskrit', 'French', 'Spanish', 'German', 'Arabic', 'Chinese', 'Japanese', 'Korean', 'Portuguese', 'Russian', 'Italian', 'Dutch'];
const langList = langs.map(l => `'${l}'`).join(', ');

const newS15 = `  // Language multi-select state
  final Set<String> _selectedLanguages = {};
  static const _allLanguages = [${langList}];

  Widget _s15Preferences() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header('Languages you speak', 'Select all that apply'),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _selectedLanguages.isEmpty
                  ? 'None selected'
                  : '\${_selectedLanguages.length} language\${_selectedLanguages.length > 1 ? "s" : ""} selected',
              style: GoogleFonts.inter(color: _cyan, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _allLanguages.map((lang) {
              final sel = _selectedLanguages.contains(lang);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (sel) { _selectedLanguages.remove(lang); }
                    else { _selectedLanguages.add(lang); }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? _cyan.withValues(alpha: 0.12) : _card,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: sel ? _cyan : _gb, width: sel ? 1.5 : 1),
                    boxShadow: sel ? [BoxShadow(color: _cyan.withValues(alpha: 0.15), blurRadius: 8)] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sel) ...[
                        const Icon(Icons.check_circle, color: _cyan, size: 14),
                        const SizedBox(width: 6),
                      ],
                      Text(lang, style: GoogleFonts.inter(
                        color: sel ? _cyan : _txt2,
                        fontSize: 14,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }`;

c = c.slice(0, start) + newS15 + c.slice(end);
console.log('Replaced _s15Preferences');

// ── 2. Remove _toggleRow helper (no longer needed) ──
// Find it and remove
const toggleMarker = '  Widget _toggleRow(';
const tStart = c.indexOf(toggleMarker);
if (tStart >= 0) {
  let td = 0, tin = false, tend = -1;
  for (let i = tStart; i < c.length; i++) {
    if (c[i] === '{') { td++; tin = true; }
    else if (c[i] === '}') { td--; if (tin && td === 0) { tend = i + 1; break; } }
  }
  c = c.slice(0, tStart) + c.slice(tend);
  console.log('Removed _toggleRow');
}

// ── 3. Remove bio field from _s0BasicInfo (search for the specific pattern) ──
// The bio field appears right before closing of the children list
c = c.replace(/\s*const SizedBox\(height: 16\),\s*\n\s*_inputField\('Bio.*?_bioCtrl.*?\),/g, '');
console.log('Attempted bio removal from s0');

// ── 4. Update validation: remove bio check from case 0 ──
c = c.replace(
  /if \(_bioCtrl\.text\.trim\(\)\.isEmpty\) \{\s*[\r\n]+\s*_showError\('Please write a short bio about yourself\.'\);[\s\S]*?return false;\s*[\r\n]+\s*\}\s*[\r\n]+\s*/g,
  ''
);
console.log('Removed bio validation');

// ── 5. Update validation: step 15 change from langCtrl to selectedLanguages ──
c = c.replace(
  /if \(_langCtrl\.text\.trim\(\)\.isEmpty\) \{ _showError\('Please enter the languages you speak\.'\); return false; \}/,
  "if (_selectedLanguages.isEmpty) { _showError('Please select at least 1 language you speak.'); return false; }"
);
console.log('Updated lang validation');

// ── 6. Update _completeOnboarding to save languages ──
c = c.replace(/'languages': _langCtrl\.text\.trim\(\),/, "'languages': _selectedLanguages.toList(),");
c = c.replace(/'lang': _langCtrl\.text\.trim\(\),/, "'languages': _selectedLanguages.toList(),");
// If there's no languages key at all yet, add it after interests
if (!c.includes("'languages':")) {
  c = c.replace(
    "'interests': _selectedInterests.toList(),",
    "'interests': _selectedInterests.toList(),\n          'languages': _selectedLanguages.toList(),"
  );
}
console.log('Updated languages in upsert');

fs.writeFileSync('lib/onboarding_screen.dart', c, 'utf8');
console.log('All changes applied successfully!');
